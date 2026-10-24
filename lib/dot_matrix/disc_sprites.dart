import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Pre-rendered images of one flip-dot disc and its mount, drawn once per
/// size and stamped across the board with [Canvas.drawRawAtlas].
///
/// All sprites share one atlas image laid out in a row of square cells:
/// the socket the disc sits in, its soft shadow, the bright face (white, to
/// be tinted per disc) and the dark back.
class DiscSprites {
  DiscSprites._(this.image, this.cell, this.pixelRatio);

  static const socket = 0;
  static const shadow = 1;
  static const face = 2;
  static const back = 3;

  final ui.Image image;

  /// Side of one sprite cell, in physical pixels.
  final double cell;

  /// Physical pixels per logical pixel the sprites were drawn at.
  final double pixelRatio;

  /// Source rectangle of sprite [index] within [image].
  Rect source(int index) => Rect.fromLTWH(index * cell, 0, cell, cell);

  static DiscSprites? _cached;
  static (double, double, bool)? _cachedKey;

  /// Sprites for discs [dot] logical pixels across, cached until the size
  /// or shape changes.
  static DiscSprites of(double dot, double pixelRatio, {required bool round}) {
    final key = (dot, pixelRatio, round);
    final cached = _cached;
    if (cached != null && _cachedKey == key) return cached;
    cached?.image.dispose();
    final sprites = _draw(dot, pixelRatio, round);
    _cached = sprites;
    _cachedKey = key;
    return sprites;
  }

  static DiscSprites _draw(double dot, double pixelRatio, bool round) {
    final d = dot * pixelRatio; // disc diameter in physical pixels
    // Room around the disc for the socket rim and the shadow's blur.
    final cell = (d * 1.5).ceilToDouble().clamp(4.0, 512.0);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = d / 2;

    Path shape(Offset c, double radius) {
      final bounds = Rect.fromCircle(center: c, radius: radius);
      if (round) return Path()..addOval(bounds);
      return Path()..addRRect(
        RRect.fromRectAndRadius(bounds, Radius.circular(radius * 0.22)),
      );
    }

    Offset center(int index) => Offset(index * cell + cell / 2, cell / 2);

    // Socket: a recess slightly larger than the disc, darker towards the
    // top-left where the rim shades it.
    {
      final c = center(socket);
      final rect = Rect.fromCircle(center: c, radius: r * 1.12);
      canvas.drawPath(
        shape(c, r * 1.12),
        Paint()
          ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
            const Color(0x66000000),
            const Color(0x14000000),
          ]),
      );
      canvas.drawPath(
        shape(c, r * 1.12),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, d * 0.03)
          ..color = const Color(0x18FFFFFF),
      );
    }

    // Shadow the disc casts down and to the right onto the board.
    {
      final c = center(shadow) + Offset(d * 0.06, d * 0.09);
      canvas.drawPath(
        shape(c, r * 0.98),
        Paint()
          ..color = const Color(0x8C000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.06),
      );
    }

    // Face: matte paint lit from the top left, with a darker rim and a
    // faint sheen. Drawn in greys so each disc can tint it its own color.
    {
      final c = center(face);
      final rect = Rect.fromCircle(center: c, radius: r);
      final path = shape(c, r);
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            c + Offset(-r * 0.35, -r * 0.4),
            r * 1.6,
            [
              const Color(0xFFFFFFFF),
              const Color(0xFFE6E6E6),
              const Color(0xFFB4B4B4),
            ],
            [0, 0.55, 1],
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
            const Color(0x00000000),
            const Color(0x26000000),
          ]),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, d * 0.045)
          ..color = const Color(0x40000000),
      );
      // The pivot axle across the middle, just visible in the paint.
      canvas.drawLine(
        Offset(c.dx - r * 0.92, c.dy),
        Offset(c.dx + r * 0.92, c.dy),
        Paint()
          ..strokeWidth = math.max(0.5, d * 0.025)
          ..color = const Color(0x14000000),
      );
    }

    // Back: black matte with a soft highlight, so even unlit discs read as
    // physical objects.
    {
      final c = center(back);
      final path = shape(c, r);
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            c + Offset(-r * 0.35, -r * 0.4),
            r * 1.6,
            [const Color(0xFF6A6A6A), const Color(0xFF3C3C3C)],
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, d * 0.045)
          ..color = const Color(0x59000000),
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(cell.toInt() * 4, cell.toInt());
    picture.dispose();
    return DiscSprites._(image, cell, pixelRatio);
  }
}
