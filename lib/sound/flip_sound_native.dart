import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'click_synth.dart';
import 'flip_sound.dart';

FlipSound createFlipSound() => _NativeFlipSound();

/// Native platforms: pre-rendered bursts of 1..N clicks, picked to match how
/// many discs land in each 30 ms window.
class _NativeFlipSound extends FlipSound {
  static const _levels = [1, 3, 8, 20, 48];
  static const _windowMs = 30;

  final _pools = <int, AudioPool>{};
  Future<void>? _loading;
  final _pending = <int, int>{};

  Future<void> _load() async {
    final dir = await Directory.systemTemp.createTemp('dotty_flip');
    for (final level in _levels) {
      final file = File('${dir.path}/flip_$level.wav');
      await file.writeAsBytes(encodeWav(synthesizeBurst(level, seed: level)));
      _pools[level] = await AudioPool.create(
        source: DeviceFileSource(file.path),
        maxPlayers: 4,
      );
    }
  }

  @override
  void unlock() {
    _loading ??= _load().catchError((Object e) {
      debugPrint('Flip sound unavailable: $e');
    });
  }

  @override
  void click(int count, double delay) {
    if (count <= 0 || volume <= 0) return;
    unlock();
    final now = DateTime.now().millisecondsSinceEpoch;
    final at = now + (delay * 1000).round();
    // Clicks landing in the same window share one burst, played when the
    // first of them lands.
    final slot = at ~/ _windowMs;
    final before = _pending[slot] ?? 0;
    _pending[slot] = before + count;
    if (before > 0) return;
    Timer(
      Duration(milliseconds: at - now),
      () => _play(_pending.remove(slot) ?? 0),
    );
  }

  void _play(int count) {
    if (count <= 0 || _pools.isEmpty) return;
    var level = _levels.first;
    for (final l in _levels) {
      if (l <= count) level = l;
    }
    _pools[level]
        ?.start(volume: volume)
        .then((_) {}, onError: (Object e) => debugPrint('Flip sound: $e'));
  }
}
