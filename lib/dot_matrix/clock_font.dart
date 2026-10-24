import 'dart:math' as math;
import 'dart:typed_data';

import '../models/show.dart';
import 'dot_bitmap.dart';

/// Segments a–g lit for each digit, as in a seven-segment display:
/// a top, b upper right, c lower right, d bottom, e lower left,
/// f upper left, g middle.
const _digitSegments = {
  '0': 'abcdef',
  '1': 'bc',
  '2': 'abged',
  '3': 'abgcd',
  '4': 'fgbc',
  '5': 'afgcd',
  '6': 'afgedc',
  '7': 'abc',
  '8': 'abcdefg',
  '9': 'abcdfg',
};

/// A bit grid being drawn into.
class _Canvas {
  _Canvas(this.width, this.height) : bits = Uint8List(width * height);

  final int width;
  final int height;
  final Uint8List bits;

  void fill(int x0, int y0, int x1, int y1) {
    for (var y = math.max(0, y0); y < math.min(height, y1); y++) {
      for (var x = math.max(0, x0); x < math.min(width, x1); x++) {
        bits[y * width + x] = 1;
      }
    }
  }
}

/// Glyph metrics for digits [h] dots tall.
class _Metrics {
  _Metrics(this.h, {required bool bold})
    : w = math.max(3, (h * 0.56).round()),
      s = math.max(1, (h / (bold ? 6 : 8)).round());

  final int h;

  /// Digit width.
  final int w;

  /// Stroke thickness.
  final int s;

  int get gap => s;

  int widthOf(String ch) => switch (ch) {
    ':' => s,
    ' ' => (w * 0.6).round(),
    '/' => w,
    _ => w,
  };

  int widthOfText(String text) {
    var total = 0;
    for (var i = 0; i < text.length; i++) {
      total += widthOf(text[i]) + (i == 0 ? 0 : gap);
    }
    return total;
  }
}

void _drawChar(_Canvas canvas, String ch, int x, int top, _Metrics m) {
  final h = m.h, w = m.w, s = m.s;
  final mid = top + (h - s) ~/ 2;
  switch (ch) {
    case ':':
      canvas.fill(
        x,
        top + (h * 0.28).round(),
        x + s,
        top + (h * 0.28).round() + s,
      );
      canvas.fill(
        x,
        top + (h * 0.68).round(),
        x + s,
        top + (h * 0.68).round() + s,
      );
    case '/':
      for (var y = 0; y < h; y++) {
        final cx = x + ((w - s) * (h - 1 - y) / math.max(1, h - 1)).round();
        canvas.fill(cx, top + y, cx + s, top + y + 1);
      }
    case ' ':
      break;
    default:
      final segments = _digitSegments[ch];
      if (segments == null) return;
      for (final seg in segments.split('')) {
        switch (seg) {
          case 'a':
            canvas.fill(x, top, x + w, top + s);
          case 'b':
            canvas.fill(x + w - s, top, x + w, mid + s);
          case 'c':
            canvas.fill(x + w - s, mid, x + w, top + h);
          case 'd':
            canvas.fill(x, top + h - s, x + w, top + h);
          case 'e':
            canvas.fill(x, mid, x + s, top + h);
          case 'f':
            canvas.fill(x, top, x + s, mid + s);
          case 'g':
            canvas.fill(x, mid, x + w, mid + s);
        }
      }
  }
}

/// The current [time] in [format] as seven-segment digits [rows] dots tall
/// (with a small margin), as large as fits [maxWidth] columns. Digits stay
/// crisp at sizes where a regular font would smear, like a real dot-matrix
/// clock. The 오전/오후 of [ClockFormat.hm12] is set in the system font.
Future<DotBitmap> rasterizeClock(
  DateTime time,
  ClockFormat format, {
  required int rows,
  int? maxWidth,
  bool bold = true,
}) async {
  final full = formatClock(time, format);
  // The Hangul half-day label is drawn separately; the rest is digits.
  final label = format == ClockFormat.hm12 ? full.split(' ').first : null;
  final digits = label == null ? full : full.substring(label.length + 1);

  final margin = rows >= 10 ? 1 : 0;
  var h = rows - 2 * margin;
  DotBitmap? labelBitmap;
  int labelGap(_Metrics m) => label == null ? 0 : m.w;

  Future<int> totalWidth(_Metrics m) async {
    var width = m.widthOfText(digits);
    if (label != null) {
      labelBitmap = await rasterizeText(
        label,
        rows: math.max(5, (m.h * 0.6).round()),
        bold: bold,
      );
      width += labelBitmap!.width + labelGap(m);
    }
    return width;
  }

  var metrics = _Metrics(h, bold: bold);
  var width = await totalWidth(metrics);
  while (maxWidth != null && width > maxWidth && h > 5) {
    h--;
    metrics = _Metrics(h, bold: bold);
    width = await totalWidth(metrics);
  }

  final canvas = _Canvas(width, rows);
  final top = (rows - h) ~/ 2;
  var x = 0;
  final lb = labelBitmap;
  if (lb != null) {
    // Sits on the digits' baseline, like a small unit label.
    final lt = top + h - lb.rows;
    for (var y = 0; y < lb.rows; y++) {
      for (var lx = 0; lx < lb.width; lx++) {
        if (lb.isOn(lx, y)) canvas.fill(lx, lt + y, lx + 1, lt + y + 1);
      }
    }
    x = lb.width + labelGap(metrics);
  }
  for (var i = 0; i < digits.length; i++) {
    if (i > 0) x += metrics.gap;
    _drawChar(canvas, digits[i], x, top, metrics);
    x += metrics.widthOf(digits[i]);
  }
  return DotBitmap(width, rows, canvas.bits);
}
