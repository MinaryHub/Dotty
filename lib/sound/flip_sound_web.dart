import 'dart:js_interop';
import 'dart:math' as math;

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
  final _rnd = math.Random();
  bool _listening = false;

  web.AudioContext _context() {
    final existing = _ctx;
    if (existing != null) return existing;
    final ctx = web.AudioContext();
    _master = ctx.createGain()..connect(ctx.destination);
    for (var v = 0; v < 8; v++) {
      final samples = synthesizeClick(v);
      final buffer = ctx.createBuffer(1, samples.length, clickSampleRate);
      buffer.copyToChannel(samples.toJS, 0);
      _clicks.add(buffer);
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
    for (var i = 0; i < voices; i++) {
      final source = ctx.createBufferSource()
        ..buffer = _clicks[_rnd.nextInt(_clicks.length)]
        ..playbackRate.value = 0.9 + _rnd.nextDouble() * 0.2;
      final gain = ctx.createGain()
        ..gain.value = level * (0.7 + _rnd.nextDouble() * 0.3);
      source.connect(gain);
      gain.connect(_master!);
      source.start(start + _rnd.nextDouble() * 0.008);
    }
  }
}
