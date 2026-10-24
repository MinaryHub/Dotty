import 'dart:convert';
import 'dart:typed_data';

import 'package:dotty/models/show.dart';
import 'package:dotty/models/show_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('show survives an encode/decode round trip, images included', () {
    final show = Show(
      panel: const PanelSettings(rows: 32, shape: DotShape.square),
      scenes: [
        Scene(id: 'a', text: '테스트', blink: true, passes: 3),
        Scene(
          id: 'b',
          kind: SceneKind.image,
          image: Uint8List.fromList([1, 2, 3, 250]),
          imageColorMode: ImageColorMode.mono,
          durationMode: DurationMode.seconds,
          durationSeconds: 7,
          transition: SceneTransition.slideUp,
        ),
      ],
    );
    final decoded = Show.decode(show.encode());
    expect(jsonEncode(decoded.toJson()), jsonEncode(show.toJson()));
    expect(decoded.scenes[1].image, [1, 2, 3, 250]);
  });

  test('corrupt or partial saves fall back to defaults', () {
    expect(Show.decode('not json').scenes, isNotEmpty);
    expect(Show.decode('{"scenes": []}').scenes, isNotEmpty);
    final s = Show.decode(
      '{"panel": {"rows": 999}, "scenes": [{"id": "x", "shape": 1}, '
      '{"id": "x", "image": "%%%"}]}',
    );
    expect(s.panel.rows, PanelSettings.maxRows);
    expect(s.scenes.length, 2);
    expect(s.scenes[0].id, isNot(s.scenes[1].id));
    expect(s.scenes[1].image, isNull);
  });

  test('a version 1 save becomes a one-scene show', () {
    final legacy = jsonEncode({
      'text': 'OLD',
      'rows': 16,
      'dotColor': 0xFF00FF00,
      'direction': 'none',
      'glow': false,
    });
    final show = Show.decodeLegacy(legacy)!;
    expect(show.scenes.single.text, 'OLD');
    expect(show.scenes.single.dotColor, const Color(0xFF00FF00));
    expect(show.scenes.single.direction, MarqueeDirection.none);
    expect(show.panel.rows, 16);
    expect(show.panel.glow, false);
  });

  test('static scenes time out by seconds even in passes mode', () {
    const s = Scene(id: 'a', direction: MarqueeDirection.none);
    expect(s.usesPasses, isFalse);
    expect(s.copyWith(direction: MarqueeDirection.left).usesPasses, isTrue);
  });

  test('store edits scenes', () {
    final store = ShowStore.memory();
    final first = store.value.scenes.first.id;
    final count = store.value.scenes.length;

    final copy = store.duplicateScene(first);
    expect(store.value.scenes[1].id, copy);
    store.updateScene(copy, (s) => s.copyWith(text: 'X'));
    expect(store.value.scenes[1].text, 'X');

    store.moveScene(1, 0);
    expect(store.value.scenes.first.id, copy);

    store.removeScene(copy);
    expect(store.value.scenes.length, count);
    while (store.value.scenes.length > 1) {
      store.removeScene(store.value.scenes.last.id);
    }
    store.removeScene(store.value.scenes.single.id);
    expect(store.value.scenes, hasLength(1), reason: 'never empty');
    store.dispose();
  });

  test('the old blink-fast flip time is upgraded, chosen times kept', () {
    PanelSettings flip(double v) => PanelSettings.fromJson({'flipSeconds': v});
    expect(flip(0.19).flipSeconds, const PanelSettings().flipSeconds);
    expect(flip(0.3).flipSeconds, 0.3);
  });
}
