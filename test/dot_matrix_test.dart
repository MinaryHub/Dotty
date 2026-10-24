import 'package:dotty/dot_matrix/dot_bitmap.dart';
import 'package:dotty/dot_matrix/dot_matrix_painter.dart';
import 'package:dotty/models/show.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int src(int c, double scroll, MarqueeDirection dir) => sourceColumn(
    screenColumn: c,
    screenColumns: 10,
    bitmapWidth: 4,
    scroll: scroll,
    direction: dir,
  );

  test('left scroll starts blank and enters from the right edge', () {
    for (var c = 0; c < 10; c++) {
      expect(src(c, 0, MarqueeDirection.left), lessThan(0));
    }
    expect(src(9, 1, MarqueeDirection.left), 0);
    // After a full period the text has left and the loop restarts.
    expect(src(9, 14, MarqueeDirection.left), src(9, 0, MarqueeDirection.left));
  });

  test('right scroll enters from the left edge', () {
    for (var c = 0; c < 10; c++) {
      expect(src(c, 0, MarqueeDirection.right), greaterThanOrEqualTo(4));
    }
    expect(src(0, 1, MarqueeDirection.right), 3);
  });

  test('static text is centered', () {
    expect(src(3, 0, MarqueeDirection.none), 0);
    expect(src(6, 99, MarqueeDirection.none), 3);
  });

  testWidgets('text rasterizes into lit dots', (tester) async {
    await tester.runAsync(() async {
      final bmp = await rasterizeText('AB', rows: 16);
      expect(bmp.rows, 16);
      expect(bmp.width, greaterThan(2));
      expect(bmp.litCount, greaterThan(0));
      expect((await rasterizeText('   ', rows: 16)).width, 0);

      // Ink fills the height without being clipped and is centered.
      final tall = await rasterizeText('ÁgÉ', rows: 12);
      final litRows = [
        for (var y = 0; y < tall.rows; y++)
          if (List.generate(tall.width, (x) => tall.isOn(x, y)).any((b) => b))
            y,
      ];
      expect(litRows.first, lessThanOrEqualTo(1));
      expect(litRows.last, greaterThanOrEqualTo(10));
    });
  });

  testWidgets('images rasterize to dots with their colors', (tester) async {
    await tester.runAsync(() async {
      // 8x4 image: left half red, right half transparent.
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 4, 4),
        Paint()..color = const Color(0xFFFF0000),
      );
      final img = await recorder.endRecording().toImage(8, 4);
      final png = (await img.toByteData(format: ui.ImageByteFormat.png))!;
      final normalized = await normalizeImportedImage(png.buffer.asUint8List());
      expect(normalized, isNotNull);

      final bmp = await rasterizeImage(
        normalized!,
        rows: 8,
        threshold: 0.1,
        keepColors: true,
      );
      expect(bmp.rows, 8);
      expect(bmp.width, 16, reason: 'scaled to 8 rows, aspect kept');
      expect(bmp.isOn(2, 4), isTrue);
      expect(bmp.isOn(12, 4), isFalse);
      expect(bmp.colors, isNotNull);
      bmp.dispose();

      final dark = await rasterizeImage(
        normalized,
        rows: 8,
        threshold: 0.9,
        keepColors: false,
      );
      expect(dark.litCount, 0, reason: 'red is below 90% luminance');
      expect(await normalizeImportedImage(Uint8List(10)), isNull);
    });
  });
}
