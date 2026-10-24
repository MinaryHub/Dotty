import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../models/show.dart';
import 'disc_sprites.dart';
import 'dot_bitmap.dart';
import 'flip_board.dart';

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
    final cols = columnsFor(size, rows);
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

    final offPaint = panel.offDotOpacity <= 0
        ? null
        : (Paint()
            ..color =
                (scene.usesDotColor ? scene.dotColor : const Color(0xFFFFFFFF))
                    .withValues(alpha: panel.offDotOpacity)
            ..strokeWidth = dot
            ..strokeCap = cap);
    final colors = scene.usesDotColor ? null : bitmap.colors;
    final slide = f.seconds * 0.25 % 1;

    // [tx]: x of the panel's left edge in the current canvas coordinates.
    Paint litPaint({required double tx, Color? solid}) {
      final p = Paint()
        ..strokeWidth = dot
        ..strokeCap = cap;
      if (colors != null) {
        // Each bitmap pixel lands exactly on its dot's center, so nearest
        // sampling gives every dot the color of its source pixel.
        p.shader = ui.ImageShader(
          colors,
          TileMode.clamp,
          TileMode.clamp,
          Float64List.fromList([
            pitchX, 0, 0, 0, //
            0, pitchY, 0, 0, //
            0, 0, 1, 0, //
            tx - shift * pitchX, 0, 0, 1, //
          ]),
          filterQuality: FilterQuality.none,
        );
      } else if (solid != null) {
        p.color = solid;
      } else if (scene.rainbow) {
        // Gradient slides sideways over time for a flowing rainbow.
        p.shader = ui.Gradient.linear(
          Offset(-slide * size.width, 0),
          Offset(size.width - slide * size.width, 0),
          _rainbow,
          null,
          TileMode.repeated,
        );
      } else {
        p.color = scene.dotColor;
      }
      return p;
    }

    // Discs are mechanical: they reflect light rather than glow.
    final glow = panel.glow && !panel.flipDots;
    void drawLit(Float32List points, Paint Function() paint) {
      if (points.isEmpty) return;
      if (glow) {
        canvas.drawRawPoints(
          ui.PointMode.points,
          points,
          paint()
            ..strokeWidth = dot * 1.3
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, dot * 0.5),
        );
      }
      canvas.drawRawPoints(ui.PointMode.points, points, paint());
    }

    if (flip != null) {
      // Turning columns are drawn one by one, each squeezed horizontally
      // around its own center.
      final off = Float32List(rows * 2);
      final on = Float32List(rows * 2);
      for (var c = 0; c < cols; c++) {
        final scale = flip.columnScale(c, cols);
        if (scale == null || scale < 0.02) continue;
        final src = c + shift;
        var offN = 0, onN = 0;
        for (var r = 0; r < rows; r++) {
          final y = originY + r * pitchY;
          if (ready && bitmap.isOn(src, r)) {
            on[onN++] = 0;
            on[onN++] = y;
          } else {
            off[offN++] = 0;
            off[offN++] = y;
          }
        }
        final x = originX + c * pitchX;
        canvas.save();
        canvas.translate(x, 0);
        canvas.scale(scale, 1);
        if (offPaint != null && offN > 0) {
          canvas.drawRawPoints(
            ui.PointMode.points,
            Float32List.sublistView(off, 0, offN),
            offPaint,
          );
        }
        final rainbow = colors == null && scene.rainbow
            ? _rainbowAt(x / size.width + slide)
            : null;
        drawLit(
          Float32List.sublistView(on, 0, onN),
          () => litPaint(tx: -x, solid: rainbow),
        );
        canvas.restore();
      }
      return;
    }

    final board = this.board;
    if (board != null && board.cols == cols && board.rows == rows) {
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

    final off = Float32List(cols * rows * 2);
    final on = Float32List(cols * rows * 2);
    var offN = 0, onN = 0;
    for (var c = 0; c < cols; c++) {
      final src = c + shift;
      final x = originX + c * pitchX;
      for (var r = 0; r < rows; r++) {
        final y = originY + r * pitchY;
        if (ready && bitmap.isOn(src, r)) {
          on[onN++] = x;
          on[onN++] = y;
        } else {
          off[offN++] = x;
          off[offN++] = y;
        }
      }
    }
    if (offPaint != null && offN > 0) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(off, 0, offN),
        offPaint,
      );
    }
    drawLit(Float32List.sublistView(on, 0, onN), () => litPaint(tx: 0));
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

    int shade(int argb, double f) {
      int ch(int shift) => (((argb >> shift) & 0xFF) * f).round().clamp(0, 255);
      return 0xFF000000 | ch(16) << 16 | ch(8) << 8 | ch(0);
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
          faceColors[faceN++] = shade(faceColor(c, r, x), board.tint[i]);
        } else {
          put(backRest, backN, x, y, tilt);
          backColors[backN++] = shade(0xFFFFFFFF, backLevel * board.tint[i]);
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
          ? shade(faceColor(c, r, center.dx), light)
          : shade(0xFFFFFFFF, backLevel * light);
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
      old.flip != flip;
}
