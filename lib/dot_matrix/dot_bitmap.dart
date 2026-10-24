import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A bitmap of [width] columns by [rows] rows of on/off dots, optionally
/// with a per-dot [colors] image of the same size.
class DotBitmap {
  DotBitmap(this.width, this.rows, this._bits, {this.colors})
    : assert(_bits.length == width * rows);

  DotBitmap.empty(this.rows) : width = 0, _bits = Uint8List(0), colors = null;

  final int width;
  final int rows;
  final Uint8List _bits;

  /// Colors of lit dots, one pixel per dot; null means a single dot color.
  /// Owned by this bitmap: release it with [dispose].
  final ui.Image? colors;

  void dispose() => colors?.dispose();

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

/// Turns an encoded image into dots: scaled to [rows] tall, with transparent
/// pixels and pixels darker than [threshold] (luminance 0..1) left unlit.
/// When [keepColors] is set, the bitmap carries the image's colors.
Future<DotBitmap> rasterizeImage(
  Uint8List encoded, {
  required int rows,
  required double threshold,
  required bool keepColors,
}) async {
  final ui.Image image;
  try {
    final codec = await ui.instantiateImageCodec(encoded, targetHeight: rows);
    image = (await codec.getNextFrame()).image;
    codec.dispose();
  } catch (e) {
    return DotBitmap.empty(rows);
  }
  final width = image.width;
  final height = math.min(rows, image.height);
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (data == null) {
    image.dispose();
    return DotBitmap.empty(rows);
  }

  final bits = Uint8List(width * rows);
  final top = (rows - height) ~/ 2;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final o = (y * width + x) * 4;
      final a = data.getUint8(o + 3);
      if (a < 128) continue;
      final lum =
          (0.2126 * data.getUint8(o) +
              0.7152 * data.getUint8(o + 1) +
              0.0722 * data.getUint8(o + 2)) /
          255;
      if (lum >= threshold) bits[(top + y) * width + x] = 1;
    }
  }
  if (!keepColors) {
    image.dispose();
    return DotBitmap(width, rows, bits);
  }
  if (image.height == rows) return DotBitmap(width, rows, bits, colors: image);
  // Shouldn't happen (the codec scales to [rows]), but keep the color image
  // aligned with the bits if it does.
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImage(image, Offset(0, top.toDouble()), Paint());
  final picture = recorder.endRecording();
  final aligned = await picture.toImage(width, rows);
  picture.dispose();
  image.dispose();
  return DotBitmap(width, rows, bits, colors: aligned);
}

/// Prepares a user-picked image file for storage: decodes it (any format
/// the platform supports) and re-encodes it as PNG, downscaled so that it
/// stays small enough to save with the show. Returns null if undecodable.
Future<Uint8List?> normalizeImportedImage(
  Uint8List bytes, {
  int maxHeight = 128,
  int maxWidth = 2048,
}) async {
  ui.Image? decoded;
  try {
    // ImageDescriptor would let us decode straight to the target size, but
    // the web engine doesn't implement it; decode, then scale on a canvas.
    final codec = await ui.instantiateImageCodec(bytes);
    decoded = (await codec.getNextFrame()).image;
    codec.dispose();
    final scale = math.min(
      1.0,
      math.min(maxHeight / decoded.height, maxWidth / decoded.width),
    );
    final width = math.max(1, (decoded.width * scale).round());
    final height = math.max(1, (decoded.height * scale).round());

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      decoded,
      Rect.fromLTWH(0, 0, decoded.width.toDouble(), decoded.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final scaled = await picture.toImage(width, height);
    picture.dispose();
    final png = await scaled.toByteData(format: ui.ImageByteFormat.png);
    scaled.dispose();
    return png?.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  } catch (e) {
    return null;
  } finally {
    decoded?.dispose();
  }
}
