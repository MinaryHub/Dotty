import 'package:dotty/dot_matrix/sign_geometry.dart';
import 'package:dotty/models/show.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an auto-shaped sign turns with the phone', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    late double aspect;
    Future<void> hold(Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            aspect = signAspect(context, const PanelSettings());
            return const SizedBox();
          },
        ),
      );
    }

    await hold(const Size(400, 800));
    final portrait = aspect;
    await hold(const Size(800, 400));
    final landscape = aspect;
    expect(portrait, lessThan(1));
    expect(landscape, greaterThan(1));
    expect(portrait * landscape, closeTo(1, 0.001));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
