import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../models/show.dart';
import 'disc_sprites.dart';
import 'dot_bitmap.dart';
import 'flip_board.dart';
import 'led_sprites.dart';

/// Animation state shared between the ticker and the painter.
class DotFrame {
  const DotFrame({this.scroll = 0, this.seconds = 0});

  /// Scroll position in columns since start.
  final double scroll;

  /// Wall-clock seconds since start (drives blink and rainbow).
  final double seconds;
}

/// Number of dot columns that fit [size] for a panel [rows] dots tall.
int columnsFor(Size size, int rows) {
  if (rows <= 0 || size.height <= 0) return 1;
  return math.max(1, (size.width / (size.height / rows)).floor());
}

/// Maps a screen column to a bitmap column for the given scroll state.
/// Returns values outside `0..bitmapWidth` for blank columns.
int sourceColumn({
  required int screenColumn,
  required int screenColumns,
  required int bitmapWidth,
  required double scroll,
  required MarqueeDirection direction,
}) {
  if (direction == MarqueeDirection.none) {
    return screenColumn - ((screenColumns - bitmapWidth) / 2).floor();
  }
  // One loop: content enters at one edge and fully leaves the other.
  final period = bitmapWidth + screenColumns;
  final pos = period == 0 ? 0 : scroll.floor() % period;
  return direction == MarqueeDirection.left
      ? screenColumn + pos - screenColumns
      : screenColumn + bitmapWidth - pos;
}

/// Flip-dot transition state for one of the two scenes involved: every dot
/// column turns over in a wave from left to right, showing the outgoing
/// scene on its front and the incoming scene on its back.
@immutable
class FlipState {
  const FlipState(this.progress, {required this.outgoing});

  /// Transition progress, 0..1.
  final double progress;

  /// Whether this side is the scene being flipped away.
  final bool outgoing;

  /// Share of the transition over which the wave travels across the panel;
  /// the rest is how long each column takes to turn.
  static const _spread = 0.6;

  /// How far column [c] of [cols] has turned, 0..1.
  double phase(int c, int cols) {
    final start = cols <= 1 ? 0.0 : _spread * c / (cols - 1);
    return ((progress - start) / (1 - _spread)).clamp(0.0, 1.0);
  }

  /// Horizontal squeeze of column [c] as it turns, or null while this side
  /// of the dots faces away.
  double? columnScale(int c, int cols) {
    final p = phase(c, cols);
    final s = math.cos(math.pi * p);
    if (outgoing) return p < 0.5 ? s : null;
    return p > 0.5 ? -s : null;
  }

  @override
  bool operator ==(Object other) =>
      other is FlipState &&
      other.progress == progress &&
      other.outgoing == outgoing;

  @override
  int get hashCode => Object.hash(progress, outgoing);
}

class DotMatrixPainter extends CustomPainter {
  DotMatrixPainter({
    required this.bitmap,
    required this.scene,
    required this.panel,
    required this.frame,
    this.flip,
    this.board,
    this.pixelRatio = 1,
    this.columns,
  }) : super(repaint: frame);

  final DotBitmap bitmap;
  final Scene scene;
  final PanelSettings panel;
  final ValueListenable<DotFrame> frame;

  /// Set while this scene is part of a flip transition. The background is
  /// then left to the caller so both scenes can share it.
  final FlipState? flip;

  /// The discs of a flip-dot panel; null for LEDs.
  final FlipBoard? board;

  /// Device pixels per logical pixel, so disc sprites render crisply.
  final double pixelRatio;

  /// Fixed grid width in dots; by default as many as fit.
  final int? columns;

  static const _rainbow = [
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFFFF3B30),
  ];

  /// Rainbow color at position [t] (wrapping) along the gradient.
  static Color _rainbowAt(double t) {
    final x = (t % 1) * (_rainbow.length - 1);
    final i = x.floor().clamp(0, _rainbow.length - 2);
    return Color.lerp(_rainbow[i], _rainbow[i + 1], x - i)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final flip = this.flip;
    if (flip == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = panel.backgroundColor,
      );
    }

    final rows = panel.rows;
    if (size.isEmpty) return;
    // The grid fills the whole area: rows fix the vertical pitch, and the
    // columns that fit are spread to the full width (a hair wider than tall).
    final pitchY = size.height / rows;
    final cols = columns ?? columnsFor(size, rows);
    final pitchX = size.width / cols;
    final originX = pitchX / 2;
    final originY = pitchY / 2;
    final dot = math.min(pitchX, pitchY) * panel.dotFill;
    final cap = panel.shape == DotShape.circle
        ? StrokeCap.round
        : StrokeCap.square;

    final f = frame.value;
    final lit =
        !scene.blink || ((f.seconds * scene.blinkHz * 2).floor() % 2 == 0);
    // The bitmap may briefly lag a rows change while it re-rasterizes.
    final ready = lit && bitmap.rows == rows;
    // sourceColumn is linear in the screen column: src = c + shift.
    final shift = sourceColumn(
      screenColumn: 0,
      screenColumns: cols,
      bitmapWidth: bitmap.width,
      scroll: f.scroll,
      direction: scene.direction,
    );

    final slide = f.seconds * 0.25 % 1;

    final board = this.board;
    if (flip == null &&
        board != null &&
        board.cols == cols &&
        board.rows == rows) {
      _paintBoard(
        canvas,
        board,
        size: size,
        now: f.seconds,
        cols: cols,
        rows: rows,
        pitchX: pitchX,
        pitchY: pitchY,
        dot: dot,
        round: cap == StrokeCap.round,
        shift: shift,
        slide: slide,
      );
      return;
    }

    // LEDs: each a domed lens in a socket, tinted with its own color.
    final sprites = LedSprites.of(
      dot,
      pixelRatio,
      round: cap == StrokeCap.round,
    );
    // An unlit LED shows its tinted epoxy; how much follows the setting.
    final offLevel = (panel.offDotOpacity * 1.8).clamp(0.0, 1.0);

    int colorOf(int c, int r, double x, bool on) {
      if (!scene.usesDotColor) {
        // Image colors for lit dots; unlit image dots are neutral.
        return (on ? bitmap.colorAt(c + shift, r) : null) ?? 0xFFBDBDBD;
      }
      if (scene.rainbow) return _rainbowAt(x / size.width + slide).toARGB32();
      return scene.dotColor.toARGB32();
    }

    if (flip != null) {
      // Turning columns are drawn one by one, each squeezed horizontally
      // around its own center.
      final column = _LedBatch(rows);
      for (var c = 0; c < cols; c++) {
        final scale = flip.columnScale(c, cols);
        if (scale == null || scale < 0.02) continue;
        final x = originX + c * pitchX;
        column.clear();
        for (var r = 0; r < rows; r++) {
          final on = ready && bitmap.isOn(c + shift, r);
          column.add(0, originY + r * pitchY, on, colorOf(c, r, x, on));
        }
        canvas.save();
        canvas.translate(x, 0);
        canvas.scale(scale, 1);
        _paintLeds(canvas, sprites, column, offLevel);
        canvas.restore();
      }
      return;
    }

    final leds = _LedBatch(cols * rows);
    for (var r = 0; r < rows; r++) {
      final y = originY + r * pitchY;
      for (var c = 0; c < cols; c++) {
        final x = originX + c * pitchX;
        final on = ready && bitmap.isOn(c + shift, r);
        leds.add(x, y, on, colorOf(c, r, x, on));
      }
    }
    _paintLeds(canvas, sprites, leds, offLevel);
  }

  /// Stamps [leds] in layers: sockets, the bloom of lit ones, lenses tinted
  /// with each LED's color (dimmed when unlit), the hot cores of lit dies,
  /// and the specular highlight on every lens.
  void _paintLeds(
    Canvas canvas,
    LedSprites sprites,
    _LedBatch leds,
    double offLevel,
  ) {
    final k = 1 / sprites.pixelRatio;
    final half = sprites.cell / 2;
    var litN = 0;
    for (var i = 0; i < leds.length; i++) {
      if (leds.on[i] == 1) litN++;
    }
    final offN = offLevel > 0 ? leds.length - litN : 0;
    final n = litN + offN;
    if (n == 0) return;

    // Lit LEDs first, then unlit ones, so each layer can take a prefix.
    final transforms = Float32List(n * 4);
    final tints = Int32List(n);
    final cores = Int32List(litN);
    final shine = Int32List(n);
    var li = 0, oi = litN;
    for (var i = 0; i < leds.length; i++) {
      final lit = leds.on[i] == 1;
      if (!lit && offN == 0) continue;
      final j = lit ? li++ : oi++;
      transforms[j * 4] = k;
      transforms[j * 4 + 1] = 0;
      transforms[j * 4 + 2] = leds.xy[i * 2] - k * half;
      transforms[j * 4 + 3] = leds.xy[i * 2 + 1] - k * half;
      final color = leds.color[i];
      if (lit) {
        tints[j] = color;
        cores[j] = _mix(color, 0xFFFFFFFF, 0.35);
        // The LED's own light outshines most of the reflection.
        shine[j] = 0xFF8C8C8C;
      } else {
        tints[j] = _shade(color, offLevel);
        shine[j] = 0xFF5A5A5A;
      }
    }

    final paint = Paint()..filterQuality = FilterQuality.low;
    // Light adds up: bloom and hot cores brighten what is beneath them.
    final light = Paint()
      ..filterQuality = FilterQuality.low
      ..blendMode = BlendMode.plus;
    void layer(
      int sprite,
      int count,
      Int32List? colors, {
      int from = 0,
      bool additive = false,
    }) {
      if (count <= 0) return;
      final rect = sprites.source(sprite);
      final rects = Float32List(count * 4);
      for (var j = 0; j < count; j++) {
        rects[j * 4] = rect.left;
        rects[j * 4 + 1] = rect.top;
        rects[j * 4 + 2] = rect.right;
        rects[j * 4 + 3] = rect.bottom;
      }
      canvas.drawRawAtlas(
        sprites.image,
        Float32List.sublistView(transforms, from * 4, (from + count) * 4),
        rects,
        colors == null
            ? null
            : Int32List.sublistView(colors, from, from + count),
        colors == null ? null : BlendMode.modulate,
        null,
        additive ? light : paint,
      );
    }

    layer(LedSprites.socket, n, null);
    if (panel.glow) layer(LedSprites.bloom, litN, tints, additive: true);
    layer(LedSprites.lens, n, tints);
    layer(LedSprites.core, litN, cores, additive: true);
    // Reflections only ever add light.
    layer(LedSprites.highlight, n, shine, additive: true);
  }

  /// Flip-dot board, drawn as physical discs: each sits in a socket, casts
  /// a shadow and shows a shaded face (tinted per disc) or its dark back.
  /// Resting discs are stamped in bulk from sprites; moving ones are drawn
  /// one by one, squeezed to their angle and dimmed as they turn edge-on.
  void _paintBoard(
    Canvas canvas,
    FlipBoard board, {
    required Size size,
    required double now,
    required int cols,
    required int rows,
    required double pitchX,
    required double pitchY,
    required double dot,
    required bool round,
    required int shift,
    required double slide,
  }) {
    final sprites = DiscSprites.of(dot, pixelRatio, round: round);
    final k = 1 / sprites.pixelRatio;
    final half = sprites.cell / 2;
    final n = cols * rows;

    // Unlit backs are dark; how dark follows the "unlit dot" setting.
    final backLevel = (0.22 + panel.offDotOpacity * 2).clamp(0.15, 1.0);

    int faceColor(int c, int r, double x) {
      final argb = scene.usesDotColor ? null : bitmap.colorAt(c + shift, r);
      if (argb != null) return argb;
      if (scene.rainbow) return _rainbowAt(x / size.width + slide).toARGB32();
      return scene.dotColor.toARGB32();
    }

    final all = Float32List(n * 4);
    final socketRects = Float32List(n * 4);
    final rest = Float32List(n * 4);
    final shadowRects = Float32List(n * 4);
    final faceRects = Float32List(n * 4);
    final faceColors = Int32List(n);
    final backRest = Float32List(n * 4);
    final backColors = Int32List(n);
    var restN = 0, faceN = 0, backN = 0;
    final moving = <int>[];

    void put(Float32List list, int at, double x, double y, double rot) {
      final scos = k * math.cos(rot), ssin = k * math.sin(rot);
      list[at * 4] = scos;
      list[at * 4 + 1] = ssin;
      list[at * 4 + 2] = x - scos * half + ssin * half;
      list[at * 4 + 3] = y - ssin * half - scos * half;
    }

    void rect(Float32List list, int at, Rect src) {
      list[at * 4] = src.left;
      list[at * 4 + 1] = src.top;
      list[at * 4 + 2] = src.right;
      list[at * 4 + 3] = src.bottom;
    }

    final socketSrc = sprites.source(DiscSprites.socket);
    final shadowSrc = sprites.source(DiscSprites.shadow);
    final faceSrc = sprites.source(DiscSprites.face);
    final backSrc = sprites.source(DiscSprites.back);

    for (var r = 0; r < rows; r++) {
      final y = pitchY / 2 + r * pitchY;
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        final x = pitchX / 2 + c * pitchX;
        put(all, i, x, y, 0);
        rect(socketRects, i, socketSrc);
        if (board.movingAt(i, now) && board.widthAt(i, now) < 0.999) {
          moving.add(i);
          continue;
        }
        final tilt = board.tilt[i];
        put(rest, restN, x, y, tilt);
        rect(shadowRects, restN++, shadowSrc);
        if (board.faceAt(i, now) == 1) {
          put(faceRects, faceN, x, y, tilt);
          faceColors[faceN++] = _shade(faceColor(c, r, x), board.tint[i]);
        } else {
          put(backRest, backN, x, y, tilt);
          backColors[backN++] = _shade(0xFFFFFFFF, backLevel * board.tint[i]);
        }
      }
    }
    final faceSrcRects = Float32List(faceN * 4);
    for (var j = 0; j < faceN; j++) {
      rect(faceSrcRects, j, faceSrc);
    }
    final backSrcRects = Float32List(backN * 4);
    for (var j = 0; j < backN; j++) {
      rect(backSrcRects, j, backSrc);
    }

    final atlasPaint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawRawAtlas(
      sprites.image,
      all,
      socketRects,
      null,
      null,
      null,
      atlasPaint,
    );
    if (restN > 0) {
      canvas.drawRawAtlas(
        sprites.image,
        Float32List.sublistView(rest, 0, restN * 4),
        Float32List.sublistView(shadowRects, 0, restN * 4),
        null,
        null,
        null,
        atlasPaint,
      );
    }
    if (backN > 0) {
      canvas.drawRawAtlas(
        sprites.image,
        Float32List.sublistView(backRest, 0, backN * 4),
        backSrcRects,
        Int32List.sublistView(backColors, 0, backN),
        BlendMode.modulate,
        null,
        atlasPaint,
      );
    }
    if (faceN > 0) {
      canvas.drawRawAtlas(
        sprites.image,
        Float32List.sublistView(faceRects, 0, faceN * 4),
        faceSrcRects,
        Int32List.sublistView(faceColors, 0, faceN),
        BlendMode.modulate,
        null,
        atlasPaint,
      );
    }

    // Moving discs: squeezed to their angle, darker edge-on.
    final cellSize = sprites.cell * k;
    for (final i in moving) {
      final c = i % cols, r = i ~/ cols;
      final center = Offset(pitchX / 2 + c * pitchX, pitchY / 2 + r * pitchY);
      final w = math.max(0.04, board.widthAt(i, now));
      final dst = Rect.fromCenter(
        center: center,
        width: cellSize * w,
        height: cellSize,
      );
      canvas.drawImageRect(
        sprites.image,
        shadowSrc,
        dst.shift(Offset(dot * 0.04 * (1 - w), 0)),
        atlasPaint,
      );
      final light = board.tint[i] * (0.45 + 0.55 * w);
      final lit = board.faceAt(i, now) == 1;
      final color = lit
          ? _shade(faceColor(c, r, center.dx), light)
          : _shade(0xFFFFFFFF, backLevel * light);
      canvas.drawImageRect(
        sprites.image,
        lit ? faceSrc : backSrc,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.mode(Color(color), BlendMode.modulate),
      );
    }

    // Room light: brighter from the top left, falling off towards the
    // corners like a sign lit by daylight.
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.linear(
          full.topLeft,
          full.bottomRight,
          [
            const Color(0x12FFFFFF),
            const Color(0x00000000),
            const Color(0x24000000),
          ],
          [0, 0.5, 1],
        ),
    );
    canvas.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.radial(
          full.center,
          size.longestSide * 0.72,
          [const Color(0x00000000), const Color(0x4D000000)],
          [0.55, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(DotMatrixPainter old) =>
      old.bitmap != bitmap ||
      old.scene != scene ||
      old.panel != panel ||
      old.frame != frame ||
      old.flip != flip ||
      old.columns != columns;
}

/// LEDs to draw: centers, lit flags and colors (ARGB).
class _LedBatch {
  _LedBatch(int capacity)
    : xy = Float32List(capacity * 2),
      on = Uint8List(capacity),
      color = Int32List(capacity);

  final Float32List xy;
  final Uint8List on;
  final Int32List color;
  int length = 0;

  void add(double x, double y, bool lit, int argb) {
    xy[length * 2] = x;
    xy[length * 2 + 1] = y;
    on[length] = lit ? 1 : 0;
    color[length] = argb;
    length++;
  }

  void clear() => length = 0;
}

/// [argb] with its channels scaled by [f] (opaque).
int _shade(int argb, double f) {
  int ch(int shift) => (((argb >> shift) & 0xFF) * f).round().clamp(0, 255);
  return 0xFF000000 | ch(16) << 16 | ch(8) << 8 | ch(0);
}

/// [a] blended towards [b] by [t] (opaque).
int _mix(int a, int b, double t) {
  int ch(int shift) {
    final x = (a >> shift) & 0xFF, y = (b >> shift) & 0xFF;
    return (x + (y - x) * t).round();
  }

  return 0xFF000000 | ch(16) << 16 | ch(8) << 8 | ch(0);
}
