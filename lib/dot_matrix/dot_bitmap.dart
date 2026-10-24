import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A monochrome bitmap: [width] columns by [rows] rows of on/off dots.
class DotBitmap {
  DotBitmap(this.width, this.rows, this._bits)
    : assert(_bits.length == width * rows);

  DotBitmap.empty(this.rows) : width = 0, _bits = Uint8List(0);

  final int width;
  final int rows;
  final Uint8List _bits;

  bool isOn(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= rows) return false;
    return _bits[y * width + x] != 0;
  }

  int get litCount => _bits.where((b) => b != 0).length;

  @override
  String toString() {
    final sb = StringBuffer();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < width; x++) {
        sb.write(isOn(x, y) ? '#' : '.');
      }
      sb.writeln();
    }
    return sb.toString();
  }
}

/// Renders [text] with the platform font and thresholds the result into a
/// bitmap [rows] dots tall. Any script the font supports (Latin, Hangul,
/// Kanji, emoji, ...) therefore works out of the box.
///
/// Glyph metrics differ widely between fonts, so the text is measured by its
/// actual ink: vertically centered on what is drawn, and shrunk if it would
/// not fit.
Future<DotBitmap> rasterizeText(
  String text, {
  required int rows,
  bool bold = true,
}) async {
  if (text.trim().isEmpty) return DotBitmap.empty(rows);

  var fontSize = rows * 0.9;
  var r = await _render(text, fontSize, bold);
  for (var attempt = 0; attempt < 3 && r.inkHeight > rows; attempt++) {
    fontSize *= rows / r.inkHeight;
    r = await _render(text, fontSize, bold);
  }
  if (r.inkHeight == 0) return DotBitmap.empty(rows);

  final top = r.inkTop - ((rows - r.inkHeight) / 2).floor();
  final bits = Uint8List(r.width * rows);
  for (var y = 0; y < rows; y++) {
    final sy = top + y;
    if (sy < 0 || sy >= r.height) continue;
    bits.setRange(y * r.width, (y + 1) * r.width, r.bits, sy * r.width);
  }
  return DotBitmap(r.width, rows, bits);
}

class _Rendered {
  _Rendered(this.width, this.height, this.bits) {
    for (var y = 0; y < height; y++) {
      final row = bits.sublist(y * width, (y + 1) * width);
      if (row.any((b) => b != 0)) {
        inkTop = math.min(inkTop, y);
        inkBottom = y;
      }
    }
  }

  final int width;
  final int height;
  final Uint8List bits;
  int inkTop = 1 << 30;
  int inkBottom = -1;

  int get inkHeight => inkBottom < 0 ? 0 : inkBottom - inkTop + 1;
}

Future<_Rendered> _render(String text, double fontSize, bool bold) async {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
        color: const Color(0xFFFFFFFF),
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  // One blank column of padding on each side keeps glyphs from touching the
  // edges when the text loops; vertical padding catches overhanging glyphs.
  final width = math.max(1, painter.width.ceil() + 2);
  final height = math.max(1, painter.height.ceil() + 4);
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Offset(1, 2));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  painter.dispose();

  final bits = Uint8List(width * height);
  if (data != null) {
    for (var i = 0; i < bits.length; i++) {
      // Alpha channel; text is drawn opaque white on a transparent canvas.
      if (data.getUint8(i * 4 + 3) >= 110) bits[i] = 1;
    }
  }
  return _Rendered(width, height, bits);
}
