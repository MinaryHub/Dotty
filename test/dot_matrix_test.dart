import 'package:dotty/dot_matrix/dot_bitmap.dart';
import 'package:dotty/dot_matrix/dot_matrix_painter.dart';
import 'package:dotty/models/display_settings.dart';
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
    });
  });
}
