import 'package:dotty/dot_matrix/dot_matrix_display.dart';
import 'package:dotty/dot_matrix/dot_matrix_painter.dart';
import 'package:dotty/dot_matrix/show_player.dart';
import 'package:dotty/l10n.dart';
import 'package:dotty/main.dart';
import 'package:dotty/models/show.dart';
import 'package:dotty/models/show_store.dart';
import 'package:dotty/screens/sign_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editing text updates the selected scene', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ShowStore.memory();
    await tester.pumpWidget(
      DottyApp(store: store, language: LanguageController()),
    );
    await tester.pump();

    expect(find.text('Dotty'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'OPEN 24H');
    await tester.pump();
    expect(store.value.scenes.first.text, 'OPEN 24H');

    // Adding a scene inserts it after the selection and selects it.
    final count = store.value.scenes.length;
    await tester.tap(find.text('Add text'));
    await tester.pump();
    expect(store.value.scenes.length, count + 1);
    expect(store.value.scenes[1].text, 'New scene');
    expect(find.widgetWithText(TextField, 'New scene'), findsOneWidget);
  });

  testWidgets('the interface switches between English and Korean', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final language = LanguageController();
    await tester.pumpWidget(
      DottyApp(store: ShowStore.memory(), language: language),
    );
    await tester.pump();

    expect(find.text('Fullscreen'), findsOneWidget);
    await tester.tap(find.text('한국어'));
    await tester.pump();
    expect(language.value, AppLanguage.ko);
    expect(find.text('전체 화면'), findsOneWidget);
    expect(find.text('문구 추가'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(find.text('Fullscreen'), findsOneWidget);
  });

  testWidgets('player advances through scenes and loops', (tester) async {
    final show = Show(
      panel: const PanelSettings(transitionMs: 100),
      scenes: [
        for (final id in ['a', 'b'])
          Scene(
            id: id,
            text: id,
            direction: MarqueeDirection.none,
            durationMode: DurationMode.seconds,
            durationSeconds: 1,
            transition: SceneTransition.slideLeft,
          ),
      ],
    );
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShowPlayer(show: show, onSceneChanged: changes.add),
      ),
    );

    String visible() => tester
        .widgetList<DotMatrixDisplay>(find.byType(DotMatrixDisplay))
        .last
        .scene
        .id;

    expect(visible(), 'a');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(changes, [1]);
    // Mid-transition both scenes are on screen.
    expect(find.byType(DotMatrixDisplay), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(DotMatrixDisplay), findsOneWidget);
    expect(visible(), 'b');
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 16));
    expect(changes, [1, 0]);
  });

  testWidgets('diagonal slides rise sideways, from either side', (
    tester,
  ) async {
    Future<(Offset, Offset)> midTransition(SceneTransition transition) async {
      final show = Show(
        panel: const PanelSettings(transitionMs: 1000),
        scenes: [
          for (final id in ['a', 'b'])
            Scene(
              id: id,
              text: id,
              direction: MarqueeDirection.none,
              durationMode: DurationMode.seconds,
              durationSeconds: 1,
              transition: transition,
            ),
        ],
      );
      await tester.pumpWidget(MaterialApp(home: ShowPlayer(show: show)));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 500));
      // The two scenes (an empty grid fills the uncovered band behind them).
      final displays = find.byWidgetPredicate(
        (w) => w is DotMatrixDisplay && w.scene.id != '__empty',
      );
      expect(displays, findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('uncovered-grid-left')),
        findsOneWidget,
        reason: 'the dot grid carries on where neither scene reaches',
      );
      expect(find.byKey(const ValueKey('uncovered-grid-right')), findsOne);
      final origin = tester.getTopLeft(find.byType(ShowPlayer));
      return (
        tester.getTopLeft(displays.first) - origin,
        tester.getTopLeft(displays.last) - origin,
      );
    }

    var (out, incoming) = await midTransition(SceneTransition.slideDiagLeft);
    expect(out.dx, lessThan(0), reason: 'old scene leaves to the left');
    expect(out.dy, lessThan(0), reason: '…and a little upward');
    expect(incoming.dx, greaterThan(0), reason: 'new one comes from the right');
    expect(incoming.dy, greaterThan(0), reason: '…from below');
    expect(incoming.dy.abs(), lessThan(incoming.dx.abs()), reason: 'slight');

    await tester.pumpWidget(const SizedBox());
    (out, incoming) = await midTransition(SceneTransition.slideDiagRight);
    expect(out.dx, greaterThan(0));
    expect(out.dy, lessThan(0));
    expect(incoming.dx, lessThan(0));
    expect(incoming.dy, greaterThan(0));
  });

  testWidgets('a still scene comes in again after its replay time', (
    tester,
  ) async {
    Show showWith({required bool replay}) => Show(
      panel: const PanelSettings(transitionMs: 200),
      scenes: [
        Scene(
          id: 'a',
          text: 'a',
          direction: MarqueeDirection.none,
          replay: replay,
          replaySeconds: 3,
          transition: SceneTransition.slideDiagLeft,
        ),
      ],
    );
    final entries = <int>[];
    Future<void> run(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        for (final d in tester.widgetList<DotMatrixDisplay>(
          find.byType(DotMatrixDisplay),
        )) {
          if (!entries.contains(d.entry)) entries.add(d.entry);
        }
      }
    }

    // Off: the single still scene just stays.
    await tester.pumpWidget(
      MaterialApp(home: ShowPlayer(show: showWith(replay: false))),
    );
    await run(7000);
    expect(entries, [0]);
    expect(find.byType(DotMatrixDisplay), findsOneWidget);

    // On: nothing before the time, then the old copy leaves as a new one
    // enters (two displays of the same scene, plus the grid filling the
    // band a diagonal slide leaves), then one again.
    await tester.pumpWidget(const SizedBox());
    entries.clear();
    await tester.pumpWidget(
      MaterialApp(home: ShowPlayer(show: showWith(replay: true))),
    );
    await run(2800);
    expect(entries, [0]);
    expect(find.byType(DotMatrixDisplay), findsOneWidget);
    await run(400);
    final during = tester
        .widgetList<DotMatrixDisplay>(find.byType(DotMatrixDisplay))
        .where((d) => d.scene.id != '__empty')
        .toList();
    expect(during, hasLength(2));
    expect(during.map((d) => d.scene.id).toSet(), {'a'});
    expect(during.map((d) => d.entry).toSet(), {0, 1});
    await run(600);
    expect(find.byType(DotMatrixDisplay), findsOneWidget);
    expect(
      tester.widget<DotMatrixDisplay>(find.byType(DotMatrixDisplay)).entry,
      1,
    );
    // The time counts again from when the new copy has settled (≈3.2 s),
    // so the next replay is due at ≈6.2 s.
    await run(2200);
    expect(entries, [0, 1]);
    await run(800);
    expect(entries, [0, 1, 2]);
  });

  testWidgets('editing one scene previews its replay too', (tester) async {
    final show = Show(
      panel: const PanelSettings(transitionMs: 200),
      scenes: [
        for (final id in ['a', 'b'])
          Scene(
            id: id,
            text: id,
            direction: MarqueeDirection.none,
            replay: id == 'b',
            replaySeconds: 2,
            transition: SceneTransition.fade,
          ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShowPlayer(show: show, soloSceneId: 'b'),
      ),
    );
    var sawTwo = false;
    for (var t = 0; t < 3000; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      sawTwo |= find.byType(DotMatrixDisplay).evaluate().length == 2;
    }
    expect(sawTwo, isTrue);
  });

  testWidgets('flip transition shows both scenes, then only the new one', (
    tester,
  ) async {
    final show = Show(
      panel: const PanelSettings(transitionMs: 100),
      scenes: [
        for (final id in ['a', 'b'])
          Scene(
            id: id,
            text: id,
            direction: MarqueeDirection.none,
            durationMode: DurationMode.seconds,
            durationSeconds: 1,
            transition: SceneTransition.flip,
          ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: ShowPlayer(show: show)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    final flipping = tester
        .widgetList<DotMatrixDisplay>(find.byType(DotMatrixDisplay))
        .toList();
    expect(flipping, hasLength(2));
    expect(flipping.every((d) => d.flip != null), isTrue);

    // Flip runs 2.5x the panel transition time.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 16));
    final settled = tester.widget<DotMatrixDisplay>(
      find.byType(DotMatrixDisplay),
    );
    expect(settled.scene.id, 'b');
    expect(settled.flip, isNull);
  });

  testWidgets('fullscreen sign fills the whole screen', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: SignScreen(store: ShowStore.memory())),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(ShowPlayer)), const Size(1600, 900));
    // Let the controls' auto-hide timer finish.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('flip-dot board keeps one display and flips to the next scene', (
    tester,
  ) async {
    final show = Show(
      panel: const PanelSettings(flipDots: true, transitionMs: 100),
      scenes: [
        for (final id in ['a', 'b'])
          Scene(
            id: id,
            text: id,
            direction: MarqueeDirection.none,
            durationMode: DurationMode.seconds,
            durationSeconds: 1,
          ),
      ],
    );
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShowPlayer(show: show, onSceneChanged: changes.add),
      ),
    );
    final board = find.byKey(const ValueKey('flip-board'));
    final state = tester.state(board);
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(changes, [1]);
    expect(find.byType(DotMatrixDisplay), findsOneWidget);
    expect(
      tester.state(board),
      same(state),
      reason: 'same board, not remounted',
    );
    expect(tester.widget<DotMatrixDisplay>(board).scene.id, 'b');
  });

  testWidgets('a flip-dot board clears and redraws a replayed scene', (
    tester,
  ) async {
    final show = Show(
      panel: const PanelSettings(flipDots: true, transitionMs: 100),
      scenes: [
        Scene(
          id: 'a',
          text: 'A',
          direction: MarqueeDirection.none,
          replay: true,
          replaySeconds: 2,
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: ShowPlayer(show: show)));

    // The discs' faces once they have all finished turning.
    int litDiscs() {
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(DotMatrixDisplay),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as DotMatrixPainter;
      final board = painter.board!;
      return [
        for (var i = 0; i < board.cols * board.rows; i++) board.faceAt(i, 1e9),
      ].fold(0, (a, b) => a + b);
    }

    Future<void> run(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await run(1000);
    final lit = litDiscs();
    expect(lit, greaterThan(0));
    await run(900); // t = 1.9 s
    expect(litDiscs(), lit, reason: 'not yet');
    await run(400); // replay due at 2 s: the board clears…
    expect(litDiscs(), 0);
    await run(1000); // …and draws the scene again.
    expect(litDiscs(), lit);
  });

  testWidgets('flip-dot transitions turn unchanged discs only if asked', (
    tester,
  ) async {
    Future<bool> turnsDuringChange({required bool flipUnchanged}) async {
      final show = Show(
        panel: PanelSettings(
          flipDots: true,
          transitionMs: 400,
          flipUnchanged: flipUnchanged,
        ),
        scenes: [
          // Identical content: nothing needs to flip on the change.
          for (final id in ['a', 'b'])
            Scene(
              id: id,
              text: 'A',
              direction: MarqueeDirection.none,
              durationMode: DurationMode.seconds,
              durationSeconds: 1,
              transition: SceneTransition.slideLeft,
            ),
        ],
      );
      await tester.pumpWidget(MaterialApp(home: ShowPlayer(show: show)));
      var busy = false;
      for (var t = 0; t < 2200; t += 50) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(DotMatrixDisplay),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as DotMatrixPainter;
        // Skip the first second: the scene has not changed yet.
        if (t > 1100 && painter.board!.busyAt(painter.frame.value.seconds)) {
          busy = true;
        }
      }
      await tester.pumpWidget(const SizedBox());
      return busy;
    }

    expect(await turnsDuringChange(flipUnchanged: false), isFalse);
    expect(await turnsDuringChange(flipUnchanged: true), isTrue);
  });

  testWidgets('preview and fullscreen show the same dot grid and shape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ShowStore.memory();
    await tester.pumpWidget(
      DottyApp(store: store, language: LanguageController()),
    );
    await tester.pump();

    DotMatrixDisplay mainDisplay() => tester
        .widgetList<DotMatrixDisplay>(find.byType(DotMatrixDisplay))
        .firstWhere((d) => d.columns != null);
    final previewColumns = mainDisplay().columns!;
    final previewSize = tester.getSize(find.byType(ShowPlayer));
    final rows = store.value.panel.rows;
    expect(
      previewSize.width / previewSize.height,
      closeTo(previewColumns / rows, 0.02),
    );

    await tester.tap(find.text('Fullscreen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final sign = find.descendant(
      of: find.byType(SignScreen),
      matching: find.byType(DotMatrixDisplay),
    );
    final signDisplay = tester.widget<DotMatrixDisplay>(sign.first);
    expect(signDisplay.columns, previewColumns);
    final signSize = tester.getSize(sign.first);
    expect(
      signSize.width / signSize.height,
      closeTo(previewColumns / rows, 0.02),
    );

    // A fixed ratio applies to both as well.
    store.updatePanel((p) => p.copyWith(aspectRatio: 2));
    await tester.pump();
    expect(tester.widget<DotMatrixDisplay>(sign.first).columns, rows * 2);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('fullscreen plays only the selected scene unless continuous', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ShowStore.memory();
    await tester.pumpWidget(
      DottyApp(store: store, language: LanguageController()),
    );
    await tester.pump();

    ShowPlayer signPlayer() => tester.widget<ShowPlayer>(
      find.descendant(
        of: find.byType(SignScreen),
        matching: find.byType(ShowPlayer),
      ),
    );

    // Default: just the selected (first) scene.
    await tester.tap(find.text('Fullscreen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(signPlayer().soloSceneId, store.value.scenes.first.id);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Continuous play on: the whole show.
    await tester.tap(find.text('Play all'));
    await tester.pump();
    await tester.tap(find.text('Fullscreen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(signPlayer().soloSceneId, isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('speed 0 stands the text still, centered', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DotMatrixDisplay(
          scene: Scene(id: 's', text: 'HI', speed: 0),
          panel: PanelSettings(),
          columns: 40,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(DotMatrixDisplay),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as DotMatrixPainter;
    expect(painter.scene.direction, MarqueeDirection.none);
    expect(const Scene(id: 's', speed: 0).usesPasses, isFalse);
  });

  testWidgets('a still scene ignores its speed setting', (tester) async {
    Future<DotMatrixPainter> painterFor(double speed) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DotMatrixDisplay(
            key: ValueKey(speed),
            scene: Scene(
              id: 's',
              text: 'HI',
              direction: MarqueeDirection.none,
              speed: speed,
            ),
            panel: const PanelSettings(),
            columns: 40,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      return tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(DotMatrixDisplay),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as DotMatrixPainter;
    }

    for (final speed in [0.0, 20.0, 120.0]) {
      final p = await painterFor(speed);
      expect(p.scene.direction, MarqueeDirection.none);
      expect(p.frame.value.scroll, 0, reason: 'nothing moves at speed $speed');
    }
  });
}
