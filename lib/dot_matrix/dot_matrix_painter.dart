import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../models/show.dart';
import 'dot_bitmap.dart';

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

class DotMatrixPainter extends CustomPainter {
  DotMatrixPainter({
    required this.bitmap,
    required this.scene,
    required this.panel,
    required this.frame,
  }) : super(repaint: frame);

  final DotBitmap bitmap;
  final Scene scene;
  final PanelSettings panel;
  final ValueListenable<DotFrame> frame;

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

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = panel.backgroundColor);

    final rows = panel.rows;
    if (size.isEmpty) return;
    final pitch = size.height / rows;
    final cols = columnsFor(size, rows);
    final originX = (size.width - cols * pitch) / 2 + pitch / 2;
    final originY = pitch / 2;
    final dot = pitch * panel.dotFill;
    final cap = panel.shape == DotShape.circle
        ? StrokeCap.round
        : StrokeCap.square;

    final f = frame.value;
    final lit =
        !scene.blink || ((f.seconds * scene.blinkHz * 2).floor() % 2 == 0);
    // The bitmap may briefly lag a rows change while it re-rasterizes.
    final ready = bitmap.rows == rows;

    final off = Float32List(cols * rows * 2);
    final on = Float32List(cols * rows * 2);
    var offN = 0, onN = 0;
    // sourceColumn is linear in the screen column: src = c + shift.
    final shift = sourceColumn(
      screenColumn: 0,
      screenColumns: cols,
      bitmapWidth: bitmap.width,
      scroll: f.scroll,
      direction: scene.direction,
    );
    for (var c = 0; c < cols; c++) {
      final src = c + shift;
      final x = originX + c * pitch;
      for (var r = 0; r < rows; r++) {
        final y = originY + r * pitch;
        if (lit && ready && bitmap.isOn(src, r)) {
          on[onN++] = x;
          on[onN++] = y;
        } else {
          off[offN++] = x;
          off[offN++] = y;
        }
      }
    }

    final offColor = scene.usesDotColor
        ? scene.dotColor
        : const Color(0xFFFFFFFF);
    if (panel.offDotOpacity > 0 && offN > 0) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(off, 0, offN),
        Paint()
          ..color = offColor.withValues(alpha: panel.offDotOpacity)
          ..strokeWidth = dot
          ..strokeCap = cap,
      );
    }
    if (onN == 0) return;

    final onPoints = Float32List.sublistView(on, 0, onN);
    final colors = scene.usesDotColor ? null : bitmap.colors;
    Paint litPaint() {
      final p = Paint()
        ..strokeWidth = dot
        ..strokeCap = cap;
      if (colors != null) {
        // Each bitmap pixel lands exactly on its dot's center, so nearest
        // sampling gives every dot the color of its source pixel.
        final tx = originX - (shift + 0.5) * pitch;
        p.shader = ui.ImageShader(
          colors,
          TileMode.clamp,
          TileMode.clamp,
          Float64List.fromList([
            pitch, 0, 0, 0, //
            0, pitch, 0, 0, //
            0, 0, 1, 0, //
            tx, 0, 0, 1, //
          ]),
          filterQuality: FilterQuality.none,
        );
      } else if (scene.rainbow) {
        // Gradient slides sideways over time for a flowing rainbow.
        final slide = (f.seconds * 0.25 % 1) * size.width;
        p.shader = ui.Gradient.linear(
          Offset(-slide, 0),
          Offset(size.width - slide, 0),
          _rainbow,
          null,
          TileMode.repeated,
        );
      } else {
        p.color = scene.dotColor;
      }
      return p;
    }

    if (panel.glow) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        onPoints,
        litPaint()
          ..strokeWidth = dot * 1.3
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, dot * 0.5),
      );
    }
    canvas.drawRawPoints(ui.PointMode.points, onPoints, litPaint());
  }

  @override
  bool shouldRepaint(DotMatrixPainter old) =>
      old.bitmap != bitmap ||
      old.scene != scene ||
      old.panel != panel ||
      old.frame != frame;
}
