import 'dart:math' as math;
import 'dart:typed_data';

/// Sample rate used for all synthesized flip sounds.
const clickSampleRate = 44100;

/// One flip-dot disc turning over, as a real board sounds up close:
/// a faint tick as the coil fires and the magnet lets go, the sharp slap of
/// the disc hitting its stop (a broadband transient, a bright plastic ring
/// and a low "thock" from the board), a soft tap as it rebounds, and the
/// first few reflections off the housing. [seed] varies pitch, timing and
/// color so a board full of discs doesn't sound like one sample repeated.
Float32List synthesizeClick(int seed) {
  final rnd = math.Random(seed);
  const length = clickSampleRate * 75 ~/ 1000;
  final dry = Float32List(length);

  void hit(
    double at, {
    required double level,
    required double tickHz,
    required double bodyHz,
    required double bodyLevel,
    double sharpness = 1,
  }) {
    var noise = 0.0;
    final start = (at * clickSampleRate).round();
    final end = math.min(length, start + clickSampleRate * 35 ~/ 1000);
    for (var i = start; i < end; i++) {
      final t = (i - start) / clickSampleRate;
      // Short noise burst, low-passed a little so it isn't hissy.
      noise = noise * 0.55 + (rnd.nextDouble() * 2 - 1) * 0.45;
      final transient = noise * math.exp(-t / (0.0009 * sharpness));
      final ring = math.sin(2 * math.pi * tickHz * t) * math.exp(-t / 0.0032);
      final thock = math.sin(2 * math.pi * bodyHz * t) * math.exp(-t / 0.007);
      dry[i] += level * (0.9 * transient + 0.6 * ring + bodyLevel * thock);
    }
  }

  final tick = 3000 + rnd.nextDouble() * 1800;
  final body = 800 + rnd.nextDouble() * 450;
  final impact = 0.005 + rnd.nextDouble() * 0.003;
  // Coil fires / magnet releases.
  hit(
    0,
    level: 0.16,
    tickHz: tick * 1.6,
    bodyHz: body,
    bodyLevel: 0,
    sharpness: 0.6,
  );
  // Disc slaps into its stop.
  hit(
    impact,
    level: 1,
    tickHz: tick,
    bodyHz: body,
    bodyLevel: 0.45 + rnd.nextDouble() * 0.2,
  );
  // Rebound tap, in step with the bounce drawn on screen.
  hit(
    impact + 0.022 + rnd.nextDouble() * 0.008,
    level: 0.22 + rnd.nextDouble() * 0.08,
    tickHz: tick * 1.1,
    bodyHz: body * 1.2,
    bodyLevel: 0.2,
  );

  // Early reflections off the sign's housing, each a little duller.
  final out = Float32List.fromList(dry);
  for (final (ms, gain) in [(7.0, 0.22), (13.0, 0.14), (23.0, 0.08)]) {
    final d = (ms / 1000 * clickSampleRate).round();
    var lp = 0.0;
    for (var i = d; i < length; i++) {
      lp = lp * 0.6 + dry[i - d] * 0.4;
      out[i] += lp * gain;
    }
  }

  var peak = 0.0;
  for (final v in out) {
    peak = math.max(peak, v.abs());
  }
  for (var i = 0; i < length; i++) {
    out[i] *= 0.9 / peak;
  }
  return out;
}

/// The low "thump" of the whole sign frame when many discs land at once.
Float32List synthesizeThump(int seed) {
  final rnd = math.Random(seed);
  const length = clickSampleRate * 140 ~/ 1000;
  final out = Float32List(length);
  final f0 = 85 + rnd.nextDouble() * 30;
  var noise = 0.0;
  var phase = 0.0;
  for (var i = 0; i < length; i++) {
    final t = i / clickSampleRate;
    // Pitch sags a little as the panel's vibration dies away.
    phase += 2 * math.pi * f0 * (1 - 0.25 * t / 0.14) / clickSampleRate;
    noise = noise * 0.97 + (rnd.nextDouble() * 2 - 1) * 0.03;
    out[i] = (math.sin(phase) * 0.8 + noise * 3) * math.exp(-t / 0.035) * 0.7;
  }
  return out;
}

/// [clicks] discs flipping at random moments within [spreadMs]: from a
/// single tick up to the rattle of a whole column turning over.
Float32List synthesizeBurst(int clicks, {int spreadMs = 40, int seed = 0}) {
  final rnd = math.Random(seed);
  final spread = clickSampleRate * spreadMs ~/ 1000;
  final variants = [for (var v = 0; v < 6; v++) synthesizeClick(seed * 7 + v)];
  final out = Float32List(spread + variants.first.length);
  // Many simultaneous discs add up, but not linearly (they don't all hit
  // in phase); keep loud bursts from clipping.
  final gain = 1 / math.sqrt(math.max(1, clicks / 2));
  for (var k = 0; k < clicks; k++) {
    final at = clicks == 1 ? 0 : rnd.nextInt(spread);
    final v = variants[rnd.nextInt(variants.length)];
    final level = gain * (0.7 + rnd.nextDouble() * 0.3);
    for (var i = 0; i < v.length; i++) {
      out[at + i] += v[i] * level;
    }
  }
  if (clicks >= 8) {
    final thump = synthesizeThump(seed);
    final level = math.min(0.6, clicks / 60);
    for (var i = 0; i < thump.length && i < out.length; i++) {
      out[i] += thump[i] * level;
    }
  }
  for (var i = 0; i < out.length; i++) {
    out[i] = out[i].clamp(-1.0, 1.0);
  }
  return out;
}

/// Encodes mono samples as a 16-bit PCM WAV file.
Uint8List encodeWav(Float32List samples, {int sampleRate = clickSampleRate}) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i] * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}
