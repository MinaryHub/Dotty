import 'package:dotty/dot_matrix/clock_font.dart';
import 'package:dotty/models/show.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = DateTime(2026, 10, 24, 20, 8, 18);

  int litRows(bitmap) {
    var n = 0;
    for (var y = 0; y < bitmap.rows; y++) {
      for (var x = 0; x < bitmap.width; x++) {
        if (bitmap.isOn(x, y)) {
          n++;
          break;
        }
      }
    }
    return n;
  }

  test('digits are as large as fit the panel', () async {
    final big = await rasterizeClock(t, ClockFormat.hm, rows: 24, maxWidth: 43);
    expect(big.rows, 24);
    expect(big.width, lessThanOrEqualTo(43));
    expect(
      litRows(big),
      greaterThanOrEqualTo(12),
      reason: 'not shrunk to mush',
    );

    final seconds = await rasterizeClock(
      t,
      ClockFormat.hms,
      rows: 24,
      maxWidth: 43,
    );
    expect(seconds.width, lessThanOrEqualTo(43));
    expect(litRows(seconds), greaterThanOrEqualTo(6));

    // Without a width limit the digits fill the height (minus a margin).
    final free = await rasterizeClock(t, ClockFormat.hm, rows: 24);
    expect(litRows(free), 22);
  });

  test('different times draw different digits', () async {
    final a = await rasterizeClock(t, ClockFormat.hms, rows: 16);
    final b = await rasterizeClock(
      t.add(const Duration(seconds: 1)),
      ClockFormat.hms,
      rows: 16,
    );
    expect(a.width, b.width, reason: 'fixed-width digits: no sideways jiggle');
    expect(a.toString(), isNot(b.toString()));
  });

  testWidgets('12-hour format adds the Hangul half-day label', (tester) async {
    await tester.runAsync(() async {
      final digitsOnly = await rasterizeClock(t, ClockFormat.hm, rows: 16);
      final withLabel = await rasterizeClock(t, ClockFormat.hm12, rows: 16);
      // "8:08" + label vs "20:08": the label takes extra room.
      expect(withLabel.width, greaterThan(digitsOnly.width * 0.8));
      expect(withLabel.litCount, greaterThan(0));
    });
  });
}
