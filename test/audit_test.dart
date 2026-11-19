import 'package:dotty/dot_matrix/dot_matrix_painter.dart';
import 'package:dotty/dot_matrix/show_player.dart';
import 'package:dotty/dot_matrix/clock_font.dart';
import 'package:dotty/l10n.dart';
import 'package:dotty/main.dart';
import 'package:dotty/models/show.dart';
import 'package:dotty/models/show_store.dart';
import 'package:dotty/screens/editor/controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'picking a preset color after a custom one closes the hue slider',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = ShowStore.memory();
      await tester.pumpWidget(
        DottyApp(store: store, language: LanguageController()),
      );
      await tester.pump();
      await tester.tap(find.text('Look'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Hue'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Your own color'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Your own color'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Hue'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('#FFCC00'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('#FFCC00'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.value.scenes.first.dotColor, const Color(0xFFFFCC00));
      expect(find.text('Hue'), findsNothing);
    },
  );

  // (LEDs: a replay builds a fresh display. Text never finishes
  // rasterizing in a plain widget test, so a flip board can't be checked
  // the same way; it keeps the clock by the same rule in _rasterize.)
  for (final flipDots in [false]) {
    testWidgets('replaying a scene does not restart its flip-all clock', (
      tester,
    ) async {
      final show = Show(
        panel: PanelSettings(flipDots: flipDots, transitionMs: 100),
        scenes: [
          const Scene(
            id: 'a',
            text: 'A',
            direction: MarqueeDirection.none,
            flipAll: true,
            flipAllSeconds: 6,
            replay: true,
            replaySeconds: 2,
            transition: SceneTransition.slideLeft,
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp(home: ShowPlayer(show: show)));
      var longest = 0.0;
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<DotMatrixPainter>();
        for (final p in painters) {
          final t = p.frame.value.sceneSeconds;
          if (t > longest) longest = t;
        }
      }
      // 8 s on screen, replayed every ~2 s: the flip-all clock still
      // reaches its 6 s period.
      expect(longest, greaterThan(6));
    });
  }

  testWidgets('a still scene that leaves before its flip-all warns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ShowStore.memory(
      Show(
        panel: const PanelSettings(),
        scenes: const [
          Scene(
            id: 'a',
            direction: MarqueeDirection.none,
            durationMode: DurationMode.seconds,
            durationSeconds: 5,
            flipAll: true,
            flipAllSeconds: 10,
          ),
          Scene(id: 'b'),
        ],
      ),
    );
    await tester.pumpWidget(
      DottyApp(store: store, language: LanguageController()),
    );
    await tester.pump();
    await tester.tap(find.text('Effects'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining("won't show"), findsOneWidget);
    // One tap makes the scene stay long enough for a flip to come.
    await tester.ensureVisible(find.text('Show this scene for 12 s'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Show this scene for 12 s'));
    await tester.pump();
    expect(store.value.scenes.first.durationSeconds, 12);
    expect(find.textContaining("won't show"), findsNothing);
  });

  testWidgets('times read the same everywhere', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    expect(formatDuration(context, 0.5), '0.5 s');
    expect(formatDuration(context, 0.62), '0.62 s');
    expect(formatDuration(context, 45), '45 s');
    expect(formatDuration(context, 120), '2 min');
    expect(formatDuration(context, 90), '1 min 30 s');
    expect(DurationSlider.stops(2, 300).first, 2);
    expect(DurationSlider.stops(2, 300).last, 300);
    expect(
      DurationSlider.stops(1, 60),
      containsAll(<double>[1, 5, 10, 30, 60]),
    );
  });

  test('a 12-hour clock follows the interface language', () {
    final t = DateTime(2026, 10, 24, 14, 5);
    expect(formatClock(t, ClockFormat.hm12), '오후 2:05');
    expect(formatClock(t, ClockFormat.hm12, korean: false), '2:05 PM');
  });

  testWidgets('the 12-hour clock draws AM/PM after the digits', (tester) async {
    await tester.runAsync(() async {
      final t = DateTime(2026, 10, 24, 14, 5);
      final plain = await rasterizeClock(t, ClockFormat.hm, rows: 16);
      final english = await rasterizeClock(
        t,
        ClockFormat.hm12,
        rows: 16,
        korean: false,
      );
      expect(english.width, greaterThan(plain.width ~/ 2));
      // Digits start at the left edge; the label sits at the right end.
      bool columnLit(int x) =>
          [for (var y = 0; y < 16; y++) english.isOn(x, y)].any((on) => on);
      expect(columnLit(0) || columnLit(1), isTrue);
      expect([
        for (var x = english.width - 3; x < english.width; x++) columnLit(x),
      ], contains(true));
    });
  });

  testWidgets('resetting the sign settings can be undone', (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ShowStore.memory();
    store.updatePanel((p) => p.copyWith(rows: 40, flipDots: true));
    await tester.pumpWidget(
      DottyApp(store: store, language: LanguageController()),
    );
    await tester.pump();
    await tester.tap(find.text('Sign (all scenes)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Reset sign settings'));
    await tester.pump();
    expect(store.value.panel.rows, const PanelSettings().rows);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(store.value.panel.rows, 40);
    expect(store.value.panel.flipDots, isTrue);
  });
}
