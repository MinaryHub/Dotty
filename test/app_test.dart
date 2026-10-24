import 'package:dotty/main.dart';
import 'package:dotty/models/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home shows settings and editing text updates the store', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = SettingsStore.memory();
    await tester.pumpWidget(DottyApp(store: store));
    await tester.pump();

    expect(find.text('Dotty'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'OPEN 24H');
    await tester.pump();
    expect(store.value.text, 'OPEN 24H');

    final reset = find.text('기본값으로 초기화');
    await tester.scrollUntilVisible(
      reset,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(reset);
    await tester.pump();
    await tester.tap(reset);
    await tester.pump();
    expect(store.value.text, isNot('OPEN 24H'));
  });
}
