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
