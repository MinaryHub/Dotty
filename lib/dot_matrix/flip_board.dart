import 'dart:math' as math;
import 'dart:typed_data';

/// The discs of a flip-dot board. Each remembers the face it shows and,
/// when told to change, turns over on its own schedule, so content changes
/// ripple across the board instead of switching instantly.
class FlipBoard {
  /// How long one disc takes to turn over.
  static const flipSeconds = 0.12;

  int cols = 0;
  int rows = 0;

  /// The face each disc is heading to (1 = lit side).
  Uint8List _target = Uint8List(0);

  /// The face each disc showed before its current flip.
  Uint8List _from = Uint8List(0);

  /// When each disc's current flip starts, in seconds; may lie in the
  /// future for staggered flips.
  Float64List _flipAt = Float64List(0);

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

  double _turn(int i, double now) => (now - _flipAt[i]) / flipSeconds;

  /// The face disc [i] shows at [now] (it swaps halfway through the turn).
  int faceAt(int i, double now) => _turn(i, now) < 0.5 ? _from[i] : _target[i];

  /// How wide disc [i] looks at [now]: 1 face-on, 0 edge-on mid-turn.
  double widthAt(int i, double now) {
    final t = _turn(i, now);
    if (t <= 0 || t >= 1) return 1;
    return math.cos(math.pi * t).abs();
  }

  /// Whether any disc is still turning or waiting to turn at [now].
  bool busyAt(double now) {
    for (var i = 0; i < _flipAt.length; i++) {
      if (_turn(i, now) < 1) return true;
    }
    return false;
  }
}
