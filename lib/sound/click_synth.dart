import 'dart:math' as math;
import 'dart:typed_data';

/// Sample rate used for all synthesized flip sounds.
const clickSampleRate = 44100;

/// One flip-dot disc slapping against its stop: a sharp broadband
/// transient, a bright plastic "tick" resonance and a short low "thock"
/// from the board, all within ~30 ms. [seed] varies pitch and color so a
/// board full of discs doesn't sound like one sample repeated.
Float32List synthesizeClick(int seed) {
  final rnd = math.Random(seed);
  const length = clickSampleRate * 30 ~/ 1000;
  final out = Float32List(length);
  final tick = 3200 + rnd.nextDouble() * 1800; // Hz
  final body = 850 + rnd.nextDouble() * 400; // Hz
  final tickLevel = 0.55 + rnd.nextDouble() * 0.25;
  final bodyLevel = 0.35 + rnd.nextDouble() * 0.2;
  var noise = 0.0;
  for (var i = 0; i < length; i++) {
    final t = i / clickSampleRate;
    // Very short noise burst, low-passed a little so it isn't hissy.
    noise = noise * 0.55 + (rnd.nextDouble() * 2 - 1) * 0.45;
    final transient = noise * math.exp(-t / 0.0009);
    final ring = math.sin(2 * math.pi * tick * t) * math.exp(-t / 0.0035);
    final thock = math.sin(2 * math.pi * body * t) * math.exp(-t / 0.007);
    out[i] = 0.9 * transient + tickLevel * ring + bodyLevel * thock;
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
