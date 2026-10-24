import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Pre-rendered pieces of one LED, drawn once per size and stamped across
/// the panel with [Canvas.drawRawAtlas]: the socket it is mounted in, its
/// colored light bloom, the domed epoxy lens (shaded in greys, tinted per
/// dot), the hot core of a lit die and the specular highlight on the lens.
class LedSprites {
  LedSprites._(this.image, this.cell, this.pixelRatio);

  static const socket = 0;
  static const bloom = 1;
  static const lens = 2;
  static const core = 3;
  static const highlight = 4;
  static const _count = 5;

  final ui.Image image;

  /// Side of one sprite cell, in physical pixels.
  final double cell;

  /// Physical pixels per logical pixel the sprites were drawn at.
  final double pixelRatio;

  Rect source(int index) => Rect.fromLTWH(index * cell, 0, cell, cell);

  static LedSprites? _cached;
  static (double, double, bool)? _cachedKey;

  /// Sprites for LEDs [dot] logical pixels across, cached until the size or
  /// shape changes.
  static LedSprites of(double dot, double pixelRatio, {required bool round}) {
    final key = (dot, pixelRatio, round);
    final cached = _cached;
    if (cached != null && _cachedKey == key) return cached;
    cached?.image.dispose();
    final sprites = _draw(dot, pixelRatio, round);
    _cached = sprites;
    _cachedKey = key;
    return sprites;
  }

  static LedSprites _draw(double dot, double pixelRatio, bool round) {
    final d = dot * pixelRatio;
    // Room for the bloom, which reaches well past the lens.
    final cell = (d * 2.6).ceilToDouble().clamp(6.0, 640.0);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = d / 2;

    Path shape(Offset c, double radius) {
      final bounds = Rect.fromCircle(center: c, radius: radius);
      if (round) return Path()..addOval(bounds);
      return Path()..addRRect(
        RRect.fromRectAndRadius(bounds, Radius.circular(radius * 0.3)),
      );
    }

    Offset center(int index) => Offset(index * cell + cell / 2, cell / 2);

    // Socket: the dark collar around the lens, catching a little light on
    // its lower edge.
    {
      final c = center(socket);
      final rect = Rect.fromCircle(center: c, radius: r * 1.18);
      canvas.drawPath(
        shape(c, r * 1.18),
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
            const Color(0x8C000000),
            const Color(0x40000000),
          ]),
      );
      canvas.drawPath(
        shape(c, r * 1.18),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, d * 0.035)
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
            const Color(0x00FFFFFF),
            const Color(0x1FFFFFFF),
          ]),
      );
    }

    // Bloom: light spilling around a lit LED.
    {
      final c = center(bloom);
      canvas.drawCircle(
        c,
        r * 1.3,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            r * 1.3,
            [
              const Color(0x99FFFFFF),
              const Color(0x40FFFFFF),
              const Color(0x00FFFFFF),
            ],
            [0, 0.5, 1],
          ),
      );
    }

    // Lens: a dome, brightest a little above center where the die sits,
    // falling off to a darker rim.
    {
      final c = center(lens);
      final path = shape(c, r);
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            c + Offset(-r * 0.08, -r * 0.12),
            r * 1.15,
            [
              const Color(0xFFFFFFFF),
              const Color(0xFFF0F0F0),
              const Color(0xFFB4B4B4),
              const Color(0xFF6E6E6E),
            ],
            [0, 0.45, 0.85, 1],
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, d * 0.05)
          ..color = const Color(0x4D000000),
      );
    }

    // Core: the die itself, glowing near white when lit.
    {
      final c = center(core) + Offset(0, -r * 0.05);
      canvas.drawCircle(
        c,
        r * 0.55,
        Paint()
          ..shader = ui.Gradient.radial(c, r * 0.55, [
            const Color(0xE6FFFFFF),
            const Color(0x00FFFFFF),
          ]),
      );
    }

    // Highlight: the window's reflection on the dome, top left, plus a
    // faint rim of light along the bottom right.
    {
      final c = center(highlight);
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(-r * 0.32, -r * 0.36),
          width: r * 0.55,
          height: r * 0.38,
        ),
        Paint()
          ..color = const Color(0xB3FFFFFF)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            math.max(0.3, d * 0.03),
          ),
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.8),
        math.pi * 0.1,
        math.pi * 0.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.5, d * 0.05)
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x33FFFFFF),
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(cell.toInt() * _count, cell.toInt());
    picture.dispose();
    return LedSprites._(image, cell, pixelRatio);
  }
}
