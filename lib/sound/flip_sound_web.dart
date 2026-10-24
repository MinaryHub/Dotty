import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'click_synth.dart';
import 'flip_sound.dart';

FlipSound createFlipSound() => _WebFlipSound();

/// Web Audio: every click is scheduled on the audio clock at the moment its
/// disc lands, so a wave of flips sounds like a real board's rattle.
class _WebFlipSound extends FlipSound {
  web.AudioContext? _ctx;
  web.GainNode? _master;
  final _clicks = <web.AudioBuffer>[];
  final _thumps = <web.AudioBuffer>[];
  final _rnd = math.Random();
  bool _listening = false;

  web.AudioContext _context() {
    final existing = _ctx;
    if (existing != null) return existing;
    final ctx = web.AudioContext();
    _master = ctx.createGain()..connect(ctx.destination);
    web.AudioBuffer buffer(Float32List samples) {
      final b = ctx.createBuffer(1, samples.length, clickSampleRate);
      b.copyToChannel(samples.toJS, 0);
      return b;
    }

    for (var v = 0; v < 12; v++) {
      _clicks.add(buffer(synthesizeClick(v)));
    }
    for (var v = 0; v < 3; v++) {
      _thumps.add(buffer(synthesizeThump(v)));
    }
    _ctx = ctx;
    if (!_listening) {
      _listening = true;
      // Any later tap or key also unlocks audio.
      final resume = ((web.Event _) => unlock()).toJS;
      web.document.addEventListener('pointerdown', resume);
      web.document.addEventListener('keydown', resume);
    }
    return ctx;
  }

  @override
  void unlock() {
    final ctx = _context();
    if (ctx.state == 'suspended') ctx.resume();
  }

  @override
  void click(int count, double delay) {
    if (count <= 0 || volume <= 0) return;
    final ctx = _context();
    if (ctx.state != 'running') return;
    // A handful of real voices per bucket; louder for larger crowds.
    final voices = math.min(count, 4);
    final level = 0.35 * volume * math.min(3.0, math.sqrt(count / voices));
    final start = ctx.currentTime + math.max(0.0, delay);
    // A crowd of discs landing together also shakes the sign's frame.
    if (count >= 10) {
      _play(
        ctx,
        _thumps[_rnd.nextInt(_thumps.length)],
        start,
        volume * math.min(0.5, count / 80),
        rate: 1,
      );
    }
    for (var i = 0; i < voices; i++) {
      _play(
        ctx,
        _clicks[_rnd.nextInt(_clicks.length)],
        start + _rnd.nextDouble() * 0.008,
        level * (0.7 + _rnd.nextDouble() * 0.3),
        rate: 0.9 + _rnd.nextDouble() * 0.2,
      );
    }
  }

  void _play(
    web.AudioContext ctx,
    web.AudioBuffer buffer,
    double when,
    double level, {
    required double rate,
  }) {
    final source = ctx.createBufferSource()
      ..buffer = buffer
      ..playbackRate.value = rate;
    final gain = ctx.createGain()..gain.value = level;
    source.connect(gain);
    gain.connect(_master!);
    source.start(when);
  }
}
