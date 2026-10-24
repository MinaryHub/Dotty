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

/// Renders [text] with the platform font at a height of [rows] pixels and
/// thresholds the result into dots. Any script the system font supports
/// (Latin, Hangul, Kanji, emoji, ...) therefore works out of the box.
Future<DotBitmap> rasterizeText(
  String text, {
  required int rows,
  bool bold = true,
}) async {
  if (text.trim().isEmpty) return DotBitmap.empty(rows);

  final fontSize = rows * 0.9;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.0,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
        color: const Color(0xFFFFFFFF),
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  // One blank column of padding on each side keeps glyphs from touching the
  // edges when the text loops.
  final width = math.max(1, painter.width.ceil() + 2);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // Center the band from ascender top (~0.78em above the baseline) to
  // descender bottom (~0.2em below) rather than the whole line box, which
  // carries extra leading and would push the text upward.
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final targetBaseline = (rows - 0.98 * fontSize) / 2 + 0.78 * fontSize;
  painter.paint(canvas, Offset(1, targetBaseline - baseline));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, rows);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  painter.dispose();
  if (data == null) return DotBitmap.empty(rows);

  final bits = Uint8List(width * rows);
  for (var i = 0; i < bits.length; i++) {
    // Alpha channel; text is drawn opaque white on a transparent canvas.
    if (data.getUint8(i * 4 + 3) >= 110) bits[i] = 1;
  }
  return DotBitmap(width, rows, bits);
}
