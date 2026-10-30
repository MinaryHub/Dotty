import 'dart:convert';
import 'dart:typed_data';

import 'package:dotty/models/show.dart';
import 'package:dotty/models/show_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('show survives an encode/decode round trip, images included', () {
    final show = Show(
      panel: const PanelSettings(
        rows: 32,
        shape: DotShape.square,
        flipUnchanged: true,
      ),
      scenes: [
        Scene(
          id: 'a',
          text: '테스트\n둘째 줄',
          blink: true,
          passes: 3,
          textSize: 0.6,
          flipAll: true,
          flipAllSeconds: 9,
          replay: true,
          replaySeconds: 45,
          transition: SceneTransition.slideDiagRight,
        ),
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
    expect(decoded.panel.flipUnchanged, isTrue);
    expect(decoded.scenes[0].transition, SceneTransition.slideDiagRight);
    expect(decoded.scenes[0].replaySeconds, 45);
  });

  test('saves from before the new options keep working, options off', () {
    final show = Show.decode(
      '{"panel": {"rows": 20}, "scenes": [{"id": "x", "transition": "slideUp"}]}',
    );
    expect(show.panel.flipUnchanged, isFalse);
    expect(show.scenes.single.replay, isFalse);
    expect(show.scenes.single.replaySeconds, 10);
    // An unknown transition name (a save from a newer version) falls back.
    final odd = Show.decode('{"scenes": [{"id": "y", "transition": "warp"}]}');
    expect(odd.scenes.single.transition, SceneTransition.fade);
  });

  test('replay is due only for a still scene, after its period settled', () {
    const s = Scene(
      id: 'a',
      direction: MarqueeDirection.none,
      replay: true,
      replaySeconds: 10,
    );
    expect(s.replayDue(9.9), isFalse);
    expect(s.replayDue(10), isTrue);
    expect(s.copyWith(replay: false).replayDue(60), isFalse);
    // Scrolling text is not still; speed 0 is.
    final scrolling = s.copyWith(direction: MarqueeDirection.left, speed: 20);
    expect(scrolling.replayDue(60), isFalse);
    expect(scrolling.copyWith(speed: 0).replayDue(60), isTrue);
    // Out-of-range periods from a damaged save are clamped.
    expect(Scene.fromJson({'replaySeconds': 0.1}).replaySeconds, 2);
    expect(Scene.fromJson({'replaySeconds': 99999}).replaySeconds, 300);
  });

  test('scenes a user adds are kept on this device and come back', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ShowStore.load();
    final added = Scene(id: 'mine', text: 'My own sign', replay: true);
    store.addScene(added);
    store.dispose(); // flushes the pending write

    // A fresh start reads them back from the device's own storage.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('show_v2'), contains('My own sign'));
    final reopened = await ShowStore.load();
    final back = reopened.value.scenes.last;
    expect(back.id, 'mine');
    expect(back.text, 'My own sign');
    expect(back.replay, isTrue);
    reopened.dispose();
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

  test('clock formats', () {
    final t = DateTime(2026, 10, 24, 14, 5, 9);
    expect(formatClock(t, ClockFormat.hm), '14:05');
    expect(formatClock(t, ClockFormat.hms), '14:05:09');
    expect(formatClock(t, ClockFormat.hm12), '오후 2:05');
    expect(formatClock(t, ClockFormat.dateHm), '10/24 14:05');
    expect(
      formatClock(DateTime(2026, 1, 1, 0, 7), ClockFormat.hm12),
      '오전 12:07',
    );
    expect(
      formatClock(DateTime(2026, 1, 1, 12, 0), ClockFormat.hm12),
      '오후 12:00',
    );
  });

  test('clock scenes round-trip and use the dot color', () {
    final scene = Scene(
      id: 'c',
      kind: SceneKind.clock,
      clockFormat: ClockFormat.hms,
    );
    final back = Scene.fromJson(scene.toJson());
    expect(back.kind, SceneKind.clock);
    expect(back.clockFormat, ClockFormat.hms);
    expect(back.usesDotColor, isTrue);
    expect(
      Show.initial().scenes.any((s) => s.kind == SceneKind.clock),
      isTrue,
      reason: 'the default show demos the clock',
    );
  });

  test('flip all sweeps across the sign, then flips back', () {
    const s = Scene(id: 'a', flipAll: true, flipAllSeconds: 6);
    // Nothing until the first interval has passed.
    expect(s.flippedAt(3, 0, 10), isFalse);
    expect(s.flippedAt(6.1, 0, 10), isTrue);
    // The wave reaches the far edge later...
    expect(s.flippedAt(6.1, 9, 10), isFalse);
    expect(s.flippedAt(6.7, 9, 10), isTrue);
    // ...and everything is back after the hold.
    expect(s.flippedAt(8.5, 0, 10), isFalse);
    expect(s.flippedAt(8.5, 9, 10), isFalse);
    expect(s.copyWith(flipAll: false).flippedAt(6.1, 0, 10), isFalse);
  });

  test('a short flip period still turns back before the next flip', () {
    const s = Scene(id: 'a', flipAll: true, flipAllSeconds: 1);
    expect(s.flipAllSweep + s.flipAllHold, lessThan(1));
    expect(s.flippedAt(1.05, 0, 10), isTrue);
    expect(s.flippedAt(1.9, 0, 10), isFalse);
    expect(s.flippedAt(1.9, 9, 10), isFalse);
    expect(s.flippedAt(2.05, 0, 10), isTrue);
  });
}
