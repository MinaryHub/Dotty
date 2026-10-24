import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../models/display_settings.dart';
import 'dot_bitmap.dart';

/// Animation state shared between the ticker and the painter.
class DotFrame {
  const DotFrame({this.scroll = 0, this.seconds = 0});

  /// Scroll position in columns since start.
  final double scroll;

  /// Wall-clock seconds since start (drives blink and rainbow).
  final double seconds;
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
  // One loop: text enters at one edge and fully leaves the other.
  final period = bitmapWidth + screenColumns;
  final pos = period == 0 ? 0 : scroll.floor() % period;
  return direction == MarqueeDirection.left
      ? screenColumn + pos - screenColumns
      : screenColumn + bitmapWidth - pos;
}

class DotMatrixPainter extends CustomPainter {
  DotMatrixPainter({
    required this.bitmap,
    required this.settings,
    required this.frame,
  }) : super(repaint: frame);

  final DotBitmap bitmap;
  final DisplaySettings settings;
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
    final s = settings;
    canvas.drawRect(Offset.zero & size, Paint()..color = s.backgroundColor);

    final rows = bitmap.rows;
    if (rows == 0 || size.isEmpty) return;
    final pitch = size.height / rows;
    final cols = math.max(1, (size.width / pitch).floor());
    final originX = (size.width - cols * pitch) / 2 + pitch / 2;
    final originY = pitch / 2;
    final dot = pitch * s.dotFill;
    final cap = s.shape == DotShape.circle ? StrokeCap.round : StrokeCap.square;

    final f = frame.value;
    final lit = !s.blink || ((f.seconds * s.blinkHz * 2).floor() % 2 == 0);

    final off = Float32List(cols * rows * 2);
    final on = Float32List(cols * rows * 2);
    var offN = 0, onN = 0;
    for (var c = 0; c < cols; c++) {
      final src = sourceColumn(
        screenColumn: c,
        screenColumns: cols,
        bitmapWidth: bitmap.width,
        scroll: f.scroll,
        direction: s.direction,
      );
      final x = originX + c * pitch;
      for (var r = 0; r < rows; r++) {
        final y = originY + r * pitch;
        if (lit && bitmap.isOn(src, r)) {
          on[onN++] = x;
          on[onN++] = y;
        } else {
          off[offN++] = x;
          off[offN++] = y;
        }
      }
    }

    if (s.offDotOpacity > 0 && offN > 0) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(off, 0, offN),
        Paint()
          ..color = s.dotColor.withValues(alpha: s.offDotOpacity)
          ..strokeWidth = dot
          ..strokeCap = cap,
      );
    }
    if (onN == 0) return;

    final onPoints = Float32List.sublistView(on, 0, onN);
    Paint litPaint() {
      final p = Paint()
        ..strokeWidth = dot
        ..strokeCap = cap;
      if (s.rainbow) {
        // Gradient slides sideways over time for a flowing rainbow.
        final shift = (f.seconds * 0.25 % 1) * size.width;
        p.shader = ui.Gradient.linear(
          Offset(-shift, 0),
          Offset(size.width - shift, 0),
          _rainbow,
          null,
          TileMode.repeated,
        );
      } else {
        p.color = s.dotColor;
      }
      return p;
    }

    if (s.glow) {
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
      old.bitmap != bitmap || old.settings != settings || old.frame != frame;
}
