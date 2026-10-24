import 'dart:typed_data';

import 'package:dotty/dot_matrix/flip_board.dart';
import 'package:dotty/sound/click_synth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const flip = FlipBoard.flipSeconds;

  test('only changed discs turn, each on its own schedule', () {
    final board = FlipBoard();
    // 3x1 board, starts without animating.
    board.update(Uint8List.fromList([0, 1, 0]), 3, 1, 0, delayOf: (_, _) => 0);
    expect([for (var i = 0; i < 3; i++) board.faceAt(i, 0)], [0, 1, 0]);
    expect(board.busyAt(0), isFalse);

    final flipped = <double>[];
    board.update(
      Uint8List.fromList([1, 1, 1]),
      3,
      1,
      1,
      delayOf: (c, _) => c * 0.1,
      onFlip: flipped.add,
    );
    expect(flipped, [0.0, 0.2], reason: 'disc 1 was already lit');

    // Disc 0 turns now; disc 2 waits 0.2 s.
    expect(board.widthAt(0, 1 + flip / 4), inExclusiveRange(0, 1));
    expect(board.faceAt(0, 1 + flip / 4), 0, reason: 'old face until halfway');
    expect(board.faceAt(0, 1 + flip * 3 / 4), 1);
    expect(board.widthAt(2, 1.1), 1, reason: 'not started yet');
    expect(board.faceAt(2, 1.1), 0);
    expect(board.busyAt(1.1), isTrue);
    expect(board.faceAt(2, 1.2 + flip), 1);
    expect(board.busyAt(1.2 + flip + 1e-6), isFalse);
  });

  test('a disc reversed mid-turn turns back from the face it shows', () {
    final board = FlipBoard();
    board.update(Uint8List.fromList([0]), 1, 1, 0, delayOf: (_, _) => 0);
    board.update(Uint8List.fromList([1]), 1, 1, 1, delayOf: (_, _) => 0);
    // Past halfway it shows the lit face; flipping back starts from there.
    final t = 1 + flip * 0.75;
    board.update(Uint8List.fromList([0]), 1, 1, t, delayOf: (_, _) => 0);
    expect(board.faceAt(0, t + 0.001), 1);
    expect(board.faceAt(0, t + flip), 0);
  });

  test('resizing resets without animating', () {
    final board = FlipBoard();
    board.update(Uint8List(4), 2, 2, 0, delayOf: (_, _) => 0);
    var flips = 0;
    board.update(
      Uint8List.fromList([1, 1, 1, 1, 1, 1]),
      3,
      2,
      1,
      delayOf: (_, _) => 0,
      onFlip: (_) => flips++,
    );
    expect(flips, 0);
    expect(board.faceAt(5, 1), 1);
  });

  test('click sounds are short, audible and never clip', () {
    final click = synthesizeClick(1);
    expect(click.length, clickSampleRate * 75 ~/ 1000);
    final peak = click.map((s) => s.abs()).reduce((a, b) => a > b ? a : b);
    expect(peak, inInclusiveRange(0.2, 1.0));
    // Decays to near silence by the end.
    expect(click.last.abs(), lessThan(0.05));

    for (final n in [1, 8, 48]) {
      final burst = synthesizeBurst(n, seed: n);
      expect(burst.every((s) => s >= -1 && s <= 1), isTrue);
    }

    final wav = encodeWav(Float32List.fromList([0, 0.5, -0.5]));
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 44 + 3 * 2);
  });

  test('discs accelerate, overshoot into the stop and settle', () {
    final board = FlipBoard();
    board.update(Uint8List.fromList([0]), 1, 1, 0, delayOf: (_, _) => 0);
    board.update(Uint8List.fromList([1]), 1, 1, 1, delayOf: (_, _) => 0);
    const turn = FlipBoard.turnSeconds;
    // Slow start: less than a quarter turned after a third of the time.
    expect(board.angleAt(0, 1 + turn / 3), lessThan(3.1416 / 4));
    // Lands on its stop, then rebounds off it before resting.
    expect(board.angleAt(0, 1 + turn), closeTo(3.1416, 1e-3));
    final rebound = [
      for (var k = 1; k < 10; k++)
        board.angleAt(0, 1 + turn + FlipBoard.settleSeconds * k / 10),
    ];
    expect(rebound.any((a) => a < 3.1416 - 0.1), isTrue);
    expect(board.angleAt(0, 1 + FlipBoard.flipSeconds), closeTo(3.1416, 1e-3));
    expect(board.movingAt(0, 1 + FlipBoard.flipSeconds + 1e-6), isFalse);
  });

  test('every disc gets its own small brightness and tilt', () {
    final board = FlipBoard();
    board.update(Uint8List(64), 8, 8, 0, delayOf: (_, _) => 0);
    expect(board.tint.every((t) => t >= 0.86 && t <= 1), isTrue);
    expect(board.tilt.every((t) => t.abs() <= 0.05), isTrue);
    expect(board.tint.toSet().length, greaterThan(32));
  });
}
