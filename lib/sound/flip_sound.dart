import 'flip_sound_native.dart'
    if (dart.library.js_interop) 'flip_sound_web.dart';

/// Plays the clatter of flip-dot discs.
abstract class FlipSound {
  /// The app-wide player.
  static final FlipSound instance = createFlipSound();

  /// 0..1.
  double volume = 0.6;

  /// Call from a user gesture: browsers only start audio after one.
  void unlock();

  /// [count] discs hitting their stops [delay] seconds from now.
  void click(int count, double delay);
}
