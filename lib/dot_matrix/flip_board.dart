import 'dart:math' as math;
import 'dart:typed_data';

/// The discs of a flip-dot board. Each remembers the face it shows and,
/// when told to change, turns over on its own schedule, so content changes
/// ripple across the board instead of switching instantly.
class FlipBoard {
  /// The magnet swings a disc over in this time, accelerating as it goes…
  static const turnSeconds = 0.08;

  /// …then it slaps into its stop and rebounds a little before resting.
  static const settleSeconds = 0.11;

  /// Whole movement of one disc.
  static const flipSeconds = turnSeconds + settleSeconds;

  /// Largest rebound off the stop, in radians (~17°).
  static const _rebound = 0.3;

  /// Stretches every disc's movement (1 = [flipSeconds]).
  double timeScale = 1;

  int cols = 0;
  int rows = 0;

  /// The face each disc is heading to (1 = lit side).
  Uint8List _target = Uint8List(0);

  /// The face each disc showed before its current flip.
  Uint8List _from = Uint8List(0);

  /// When each disc's current flip starts, in seconds; may lie in the
  /// future for staggered flips.
  Float64List _flipAt = Float64List(0);

  /// Per-disc brightness (0.86..1) and resting tilt (radians): no two
  /// physical discs sit or reflect quite alike.
  Float32List tint = Float32List(0);
  Float32List tilt = Float32List(0);

  bool get isEmpty => cols == 0 || rows == 0;

  /// Brings the board to [target] (`cols * rows` faces, row by row).
  ///
  /// Discs whose face changes start turning at [now] plus `delayOf(c, r)`;
  /// [onFlip] reports each one's delay (for sound). A new size resets the
  /// board without animating.
  void update(
    Uint8List target,
    int cols,
    int rows,
    double now, {
    required double Function(int c, int r) delayOf,
    void Function(double delay)? onFlip,
  }) {
    assert(target.length == cols * rows);
    if (cols != this.cols || rows != this.rows) {
      this.cols = cols;
      this.rows = rows;
      _target = Uint8List.fromList(target);
      _from = Uint8List.fromList(target);
      _flipAt = Float64List(target.length)..fillRange(0, target.length, -1e9);
      tint = Float32List(target.length);
      tilt = Float32List(target.length);
      for (var i = 0; i < target.length; i++) {
        final c = i % cols, r = i ~/ cols;
        tint[i] = 0.86 + 0.14 * _noise(c, r, 11);
        tilt[i] = (_noise(c, r, 12) - 0.5) * 0.09;
      }
      return;
    }
    for (var i = 0; i < target.length; i++) {
      final face = target[i];
      if (face == _target[i]) continue;
      // A disc already on its way keeps turning from what it shows now.
      _from[i] = faceAt(i, now);
      _target[i] = face;
      final delay = delayOf(i % cols, i ~/ cols);
      _flipAt[i] = now + delay;
      onFlip?.call(delay);
    }
  }

  static double _noise(int c, int r, int salt) {
    final v = math.sin(c * 12.9898 + r * 78.233 + salt * 37.719) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// Rotation of disc [i] at [now], 0 (old face) to π (new face).
  double angleAt(int i, double now) {
    final t = (now - _flipAt[i]) / timeScale;
    if (t <= 0) return 0;
    if (t < turnSeconds) {
      // Pulled by the magnet: slow off the mark, fastest at the end.
      final u = t / turnSeconds;
      return math.pi * u * u * (1.6 - 0.6 * u);
    }
    if (t < flipSeconds) {
      // Bounces back off the stop and settles, like a damped spring.
      final s = (t - turnSeconds) / settleSeconds;
      return math.pi -
          _rebound * math.sin(s * math.pi * 3).abs() * math.exp(-3.5 * s);
    }
    return math.pi;
  }

  /// The face disc [i] shows at [now] (it swaps once past edge-on).
  int faceAt(int i, double now) =>
      angleAt(i, now) < math.pi / 2 ? _from[i] : _target[i];

  /// How wide disc [i] looks at [now]: 1 face-on, 0 edge-on mid-turn.
  double widthAt(int i, double now) => math.cos(angleAt(i, now)).abs();

  /// Whether disc [i] is moving (or about to) at [now].
  bool movingAt(int i, double now) =>
      now - _flipAt[i] < flipSeconds * timeScale;

  /// Whether any disc is still turning or waiting to turn at [now].
  bool busyAt(double now) {
    for (var i = 0; i < _flipAt.length; i++) {
      if (movingAt(i, now)) return true;
    }
    return false;
  }
}
