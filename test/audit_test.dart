import 'package:dotty/dot_matrix/dot_matrix_painter.dart';
import 'package:dotty/dot_matrix/show_player.dart';
import 'package:dotty/l10n.dart';
import 'package:dotty/main.dart';
import 'package:dotty/models/show.dart';
import 'package:dotty/models/show_store.dart';
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
    store.updateScene('a', (s) => s.copyWith(durationSeconds: 20));
    await tester.pump();
    expect(find.textContaining("won't show"), findsNothing);
  });
}
