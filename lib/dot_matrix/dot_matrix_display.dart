import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/show.dart';
import '../sound/flip_sound.dart';
import 'clock_font.dart';
import 'dot_bitmap.dart';
import 'dot_matrix_painter.dart';
import 'flip_board.dart';

/// An animated dot-matrix panel showing one [scene], as LEDs or as a
/// mechanical flip-dot board ([PanelSettings.flipDots]).
///
/// On a flip-dot board, giving the same display a different scene (or a new
/// [entry] of it) flips the discs over to the new content in the pattern of
/// the scene's [Scene.transition].
class DotMatrixDisplay extends StatefulWidget {
  const DotMatrixDisplay({
    super.key,
    required this.scene,
    required this.panel,
    this.paused = false,
    this.onPass,
    this.flip,
    this.entry = 0,
    this.sound = false,
    this.columns,
  });

  final Scene scene;
  final PanelSettings panel;
  final bool paused;

  /// Called with the running count each time scrolling content has fully
  /// crossed the panel.
  final ValueChanged<int>? onPass;

  /// Set while this scene takes part in a flip transition.
  final FlipState? flip;

  /// Distinguishes repeated plays of the same scene.
  final int entry;

  /// Whether flipping discs click (flip-dot boards only).
  final bool sound;

  /// Fixed number of dot columns (the sign's grid); by default as many as
  /// fit the available width.
  final int? columns;

  @override
  State<DotMatrixDisplay> createState() => _DotMatrixDisplayState();
}

class _DotMatrixDisplayState extends State<DotMatrixDisplay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _frame = ValueNotifier(const DotFrame());
  DotBitmap? _bitmap;
  int _rasterRequest = 0;
  int _columns = 1;

  Duration _lastTick = Duration.zero;
  double _scroll = 0;
  double _seconds = 0;
  int _passes = 0;

  /// [_seconds] when the shown scene came up.
  double _shownAt = 0;

  /// The scene whose content [_bitmap] holds. It lags [DotMatrixDisplay.scene]
  /// while a newly given scene is being rasterized, so the board keeps
  /// showing the old one instead of going blank.
  late Scene _shown = widget.scene;
  late int _shownEntry = widget.entry;

  final _board = FlipBoard();

  /// The time text a clock scene currently shows.
  String? _clockText;

  /// Source of the current time (replaceable in tests).
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// Transition to play on the board's next update after a scene change.
  SceneTransition? _pendingWave;

  bool get _showingCurrent =>
      _shown.id == widget.scene.id && _shownEntry == widget.entry;

  /// Look and motion come from the latest settings of the shown scene.
  Scene get _look {
    final look = _showingCurrent ? widget.scene : _shown;
    if (look.direction == MarqueeDirection.none) return look;
    // Speed 0 means standing still: show the content centered rather than
    // frozen at its scroll start (off screen).
    if (look.speed <= 0) {
      return look.copyWith(direction: MarqueeDirection.none);
    }
    return look;
  }

  @override
  void initState() {
    super.initState();
    // On the web, fonts (and per-script fallbacks such as Hangul) load lazily;
    // redraw the bitmap once they arrive instead of keeping placeholder boxes.
    PaintingBinding.instance.systemFonts.addListener(_rasterize);
    _rasterize();
    _ticker.start();
  }

  @override
  void didUpdateWidget(DotMatrixDisplay old) {
    super.didUpdateWidget(old);
    final s = widget.scene, o = old.scene;
    final contentChanged =
        s.id != o.id ||
        widget.entry != old.entry ||
        widget.columns != old.columns ||
        (s.direction == MarqueeDirection.none) !=
            (o.direction == MarqueeDirection.none) ||
        s.kind != o.kind ||
        widget.panel.rows != old.panel.rows ||
        switch (s.kind) {
          SceneKind.text =>
            s.text != o.text || s.bold != o.bold || s.textSize != o.textSize,
          SceneKind.clock => s.clockFormat != o.clockFormat || s.bold != o.bold,
          SceneKind.image =>
            s.image != o.image ||
                s.imageThreshold != o.imageThreshold ||
                s.imageColorMode != o.imageColorMode,
        };
    if (contentChanged) _rasterize();
    if (s.direction != o.direction && _showingCurrent) {
      _scroll = 0;
      _passes = 0;
    }
  }

  Future<void> _rasterize() async {
    final request = ++_rasterRequest;
    final s = widget.scene;
    final entry = widget.entry;
    final rows = widget.panel.rows;
    final image = s.image;
    final DotBitmap bitmap;
    if (s.kind == SceneKind.clock) {
      final time = now();
      _clockText = _clockKey(time, s.clockFormat);
      bitmap = await rasterizeClock(
        time,
        s.clockFormat,
        rows: rows,
        maxWidth: widget.columns,
        bold: s.bold,
        colonOn: clockColonOn(time, s.clockFormat),
      );
    } else if (s.kind == SceneKind.image) {
      bitmap = image == null
          ? DotBitmap.empty(rows)
          : await rasterizeImage(
              image,
              rows: rows,
              threshold: s.imageThreshold,
              keepColors: s.imageColorMode == ImageColorMode.original,
            );
    } else {
      bitmap = await rasterizeText(
        s.text,
        rows: rows,
        bold: s.bold,
        maxWidth: s.direction == MarqueeDirection.none ? widget.columns : null,
        size: s.textSize,
      );
    }
    // Drop stale results when the content changed again while rendering.
    if (!mounted || request != _rasterRequest) {
      bitmap.dispose();
      return;
    }
    final old = _bitmap;
    setState(() {
      _bitmap = bitmap;
      if (s.id != _shown.id || entry != _shownEntry) {
        // A different scene takes over: start it from the beginning.
        _scroll = 0;
        _passes = 0;
        _shownAt = _seconds;
        _pendingWave = s.transition;
      }
      _shown = s;
      _shownEntry = entry;
      // A still display (scene thumbnail) has no ticks to turn its discs:
      // reset them so the next build lays them out from the new content,
      // e.g. once a web font for Hangul has arrived.
      if (widget.paused) _board.cols = 0;
    });
    // Release the old image after the frame that stops painting it.
    if (old != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (widget.paused) return;
    final look = _look;
    // A clock redraws whenever what it shows changes: every second, the
    // seconds or the blinking colon (a flip board then turns just those
    // discs).
    if (widget.scene.kind == SceneKind.clock) {
      final key = _clockKey(now(), widget.scene.clockFormat);
      if (key != _clockText) {
        _clockText = key;
        _rasterize();
      }
    }
    _seconds += dt;
    if (look.direction != MarqueeDirection.none) _scroll += dt * look.speed;
    if (widget.panel.flipDots) _updateBoard(look);
    _frame.value = DotFrame(
      scroll: _scroll,
      seconds: _seconds,
      sceneSeconds: _seconds - _shownAt,
    );

    final bitmap = _bitmap;
    final onPass = widget.onPass;
    if (onPass != null &&
        bitmap != null &&
        _showingCurrent &&
        look.direction != MarqueeDirection.none) {
      final passes = (_scroll / (bitmap.width + _columns)).floor();
      if (passes > _passes) {
        _passes = passes;
        onPass(passes);
      }
    }
  }

  /// Points the discs at the faces this frame should show; changed ones
  /// start turning (and clicking).
  void _updateBoard(Scene look) {
    final bitmap = _bitmap;
    final rows = widget.panel.rows;
    final cols = _columns;
    if (bitmap == null || bitmap.rows != rows) return;
    final lit = !look.blink || ((_seconds * look.blinkHz * 2).floor() % 2 == 0);
    final shift = sourceColumn(
      screenColumn: 0,
      screenColumns: cols,
      bitmapWidth: bitmap.width,
      scroll: _scroll,
      direction: look.direction,
    );
    final target = Uint8List(cols * rows);
    final still = look.direction == MarqueeDirection.none;
    final since = _seconds - _shownAt;
    for (var c = 0; c < cols; c++) {
      final flipped = still && look.flippedAt(since, c, cols);
      for (var r = 0; r < rows; r++) {
        final on = lit && bitmap.isOn(c + shift, r);
        if (on != flipped) target[r * cols + c] = 1;
      }
    }

    final wave = _pendingWave;
    _pendingWave = null;
    final span = widget.panel.transitionMs / 1000 * 1.2;
    double delayOf(int c, int r) {
      // The driver scans the board column by column, and each coil fires
      // with a few ms of scatter.
      final scan = c * 0.0008;
      final jitter = _hash(c, r, 1) * 0.025;
      return scan +
          jitter +
          switch (wave) {
            null || SceneTransition.cut => 0,
            SceneTransition.fade => _hash(c, r, 2) * span,
            SceneTransition.slideUp =>
              (rows - 1 - r) / math.max(1, rows - 1) * span * 0.7,
            SceneTransition.slideLeft ||
            SceneTransition.flip => c / math.max(1, cols - 1) * span,
          };
    }

    // While text scrolls, discs flip at every column step; past a few
    // steps per turn the text smears, so cap the turn there. Blinking
    // discs must finish turning within one blink.
    var flipSeconds = widget.panel.flipSeconds;
    if (look.direction != MarqueeDirection.none && look.speed > 0) {
      flipSeconds = math.min(flipSeconds, 6 / look.speed);
    }
    if (look.blink) {
      flipSeconds = math.min(flipSeconds, 0.9 / (2 * look.blinkHz));
    }
    // A clock's colon blinks every half second.
    if (look.kind == SceneKind.clock) {
      flipSeconds = math.min(flipSeconds, 0.4);
    }
    _board.timeScale = flipSeconds / FlipBoard.flipSeconds;
    final sound = widget.sound && widget.panel.flipSound;
    final buckets = <int, int>{};
    _board.update(
      target,
      cols,
      rows,
      _seconds,
      delayOf: delayOf,
      onFlip: sound
          ? (delay) {
              final b = (delay / 0.01).floor();
              buckets[b] = (buckets[b] ?? 0) + 1;
            }
          : null,
    );
    if (buckets.isNotEmpty) {
      final player = FlipSound.instance..volume = widget.panel.soundVolume;
      // Discs click when they land on their stop, at the end of the turn.
      final landing = FlipBoard.turnSeconds * _board.timeScale;
      buckets.forEach((b, count) => player.click(count, b * 0.01 + landing));
    }
  }

  static String _clockKey(DateTime time, ClockFormat format) =>
      '${formatClock(time, format)}|${clockColonOn(time, format)}';

  /// Stable pseudo-random 0..1 per disc (same on every platform, unlike
  /// integer hashing, which overflows differently on the web).
  static double _hash(int c, int r, int salt) {
    final v = math.sin(c * 12.9898 + r * 78.233 + salt * 37.719) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_rasterize);
    _ticker.dispose();
    _frame.dispose();
    _bitmap?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bitmap = _bitmap ?? DotBitmap.empty(widget.panel.rows);
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _columns =
              widget.columns ??
              columnsFor(constraints.biggest, widget.panel.rows);
          // Set up the discs right away (silently) so still displays, like
          // scene thumbnails, show them too.
          if (widget.panel.flipDots &&
              (_board.cols != _columns || _board.rows != widget.panel.rows)) {
            _updateBoard(_look);
          }
          return CustomPaint(
            painter: DotMatrixPainter(
              bitmap: bitmap,
              scene: _look,
              panel: widget.panel,
              frame: _frame,
              flip: widget.flip,
              board: widget.panel.flipDots ? _board : null,
              pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
              columns: widget.columns,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
