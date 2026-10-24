import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/show.dart';
import 'dot_bitmap.dart';
import 'dot_matrix_painter.dart';

/// An animated LED dot-matrix panel showing one [scene].
class DotMatrixDisplay extends StatefulWidget {
  const DotMatrixDisplay({
    super.key,
    required this.scene,
    required this.panel,
    this.paused = false,
    this.onPass,
    this.flip,
  });

  final Scene scene;
  final PanelSettings panel;
  final bool paused;

  /// Called with the running count each time scrolling content has fully
  /// crossed the panel.
  final ValueChanged<int>? onPass;

  /// Set while this scene takes part in a flip transition.
  final FlipState? flip;

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
        s.kind != o.kind ||
        widget.panel.rows != old.panel.rows ||
        (s.kind == SceneKind.text
            ? s.text != o.text || s.bold != o.bold
            : s.image != o.image ||
                  s.imageThreshold != o.imageThreshold ||
                  s.imageColorMode != o.imageColorMode);
    if (contentChanged) _rasterize();
    if (s.direction != o.direction) {
      _scroll = 0;
      _passes = 0;
    }
  }

  Future<void> _rasterize() async {
    final request = ++_rasterRequest;
    final s = widget.scene;
    final rows = widget.panel.rows;
    final image = s.image;
    final DotBitmap bitmap;
    if (s.kind == SceneKind.image) {
      bitmap = image == null
          ? DotBitmap.empty(rows)
          : await rasterizeImage(
              image,
              rows: rows,
              threshold: s.imageThreshold,
              keepColors: s.imageColorMode == ImageColorMode.original,
            );
    } else {
      bitmap = await rasterizeText(s.text, rows: rows, bold: s.bold);
    }
    // Drop stale results when the content changed again while rendering.
    if (!mounted || request != _rasterRequest) {
      bitmap.dispose();
      return;
    }
    final old = _bitmap;
    setState(() => _bitmap = bitmap);
    // Release the old image after the frame that stops painting it.
    if (old != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (widget.paused) return;
    _seconds += dt;
    _scroll += dt * widget.scene.speed;
    _frame.value = DotFrame(scroll: _scroll, seconds: _seconds);

    final bitmap = _bitmap;
    final onPass = widget.onPass;
    if (onPass != null &&
        bitmap != null &&
        widget.scene.direction != MarqueeDirection.none) {
      final passes = (_scroll / (bitmap.width + _columns)).floor();
      if (passes > _passes) {
        _passes = passes;
        onPass(passes);
      }
    }
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
          _columns = columnsFor(constraints.biggest, widget.panel.rows);
          return CustomPaint(
            painter: DotMatrixPainter(
              bitmap: bitmap,
              scene: widget.scene,
              panel: widget.panel,
              frame: _frame,
              flip: widget.flip,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
