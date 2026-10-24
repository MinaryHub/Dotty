import 'package:dotty/dot_matrix/dot_matrix_display.dart';
import 'package:dotty/dot_matrix/show_player.dart';
import 'package:dotty/main.dart';
import 'package:dotty/models/show.dart';
import 'package:dotty/models/show_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editing text updates the selected scene', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ShowStore.memory();
    await tester.pumpWidget(DottyApp(store: store));
    await tester.pump();

    expect(find.text('Dotty'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'OPEN 24H');
    await tester.pump();
    expect(store.value.scenes.first.text, 'OPEN 24H');

    // Adding a scene inserts it after the selection and selects it.
    final count = store.value.scenes.length;
    await tester.tap(find.text('문구 추가'));
    await tester.pump();
    expect(store.value.scenes.length, count + 1);
    expect(store.value.scenes[1].text, '새 장면');
    expect(find.widgetWithText(TextField, '새 장면'), findsOneWidget);
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
}
