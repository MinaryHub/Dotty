import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/show.dart';

/// Width / height of the sign: the panel's chosen ratio, or else the shape
/// of the screen this device shows the sign on in fullscreen.
double signAspect(BuildContext context, PanelSettings panel) {
  if (panel.aspectRatio > 0) return panel.aspectRatio;
  var size = View.maybeOf(context)?.display.size ?? Size.zero;
  if (size.isEmpty) size = MediaQuery.sizeOf(context);
  if (size.isEmpty) return 16 / 9;
  final long = math.max(size.width, size.height);
  final short = math.min(size.width, size.height);
  // Phones and tablets turn: follow how the device is held right now.
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (mobile) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return portrait ? short / long : long / short;
  }
  return size.width / size.height;
}

/// Dot columns of a sign [aspect] wide for [panel]'s rows (square pitch).
int signColumns(PanelSettings panel, double aspect) =>
    math.max(1, (panel.rows * aspect).round());
