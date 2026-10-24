import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../models/show.dart';
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
        now: f.seconds,
        cols: cols,
        rows: rows,
        pitchX: pitchX,
        pitchY: pitchY,
        dot: dot,
        cap: cap,
        shift: shift,
        slide: slide,
        width: size.width,
        offPaint: offPaint,
        drawLit: drawLit,
        litPaint: () => litPaint(tx: 0),
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

  /// Flip-dot board: settled discs are batched like LEDs; turning ones are
  /// drawn one by one, squeezed to their current width, showing whichever
  /// face is towards the viewer.
  void _paintBoard(
    Canvas canvas,
    FlipBoard board, {
    required double now,
    required int cols,
    required int rows,
    required double pitchX,
    required double pitchY,
    required double dot,
    required StrokeCap cap,
    required int shift,
    required double slide,
    required double width,
    required Paint? offPaint,
    required void Function(Float32List points, Paint Function() paint) drawLit,
    required Paint Function() litPaint,
  }) {
    final off = Float32List(cols * rows * 2);
    final on = Float32List(cols * rows * 2);
    var offN = 0, onN = 0;
    final turning = <int>[];
    for (var r = 0; r < rows; r++) {
      final y = pitchY / 2 + r * pitchY;
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        if (board.widthAt(i, now) < 1) {
          turning.add(i);
          continue;
        }
        final x = pitchX / 2 + c * pitchX;
        if (board.faceAt(i, now) == 1) {
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
    drawLit(Float32List.sublistView(on, 0, onN), litPaint);

    if (turning.isEmpty) return;
    final litDisc = Paint();
    // The disc's back is dark; draw it even when unlit dots are hidden, or
    // turning discs would vanish mid-flip.
    final backDisc = Paint()
      ..color = offPaint?.color ?? const Color(0x33FFFFFF);
    for (final i in turning) {
      final c = i % cols, r = i ~/ cols;
      final center = Offset(pitchX / 2 + c * pitchX, pitchY / 2 + r * pitchY);
      final rect = Rect.fromCenter(
        center: center,
        width: math.max(1, dot * board.widthAt(i, now)),
        height: dot,
      );
      final Paint paint;
      if (board.faceAt(i, now) == 1) {
        final argb = scene.usesDotColor ? null : bitmap.colorAt(c + shift, r);
        litDisc.color = argb != null
            ? Color(argb)
            : scene.rainbow && scene.usesDotColor
            ? _rainbowAt(center.dx / width + slide)
            : scene.dotColor;
        paint = litDisc;
      } else {
        paint = backDisc;
      }
      if (cap == StrokeCap.round) {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotMatrixPainter old) =>
      old.bitmap != bitmap ||
      old.scene != scene ||
      old.panel != panel ||
      old.frame != frame ||
      old.flip != flip;
}
