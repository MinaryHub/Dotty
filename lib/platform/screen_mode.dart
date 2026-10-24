import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Must run before `runApp` on desktop.
Future<void> initWindow() async {
  if (!isDesktop) return;
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Dotty',
      size: Size(1100, 720),
      minimumSize: Size(420, 480),
      center: true,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

/// Switches the whole app into an edge-to-edge sign mode: fullscreen window
/// (desktop) or immersive system UI (Android), with the screen kept awake.
Future<void> enterSignMode() async {
  await _guard(() => WakelockPlus.enable());
  if (isDesktop) {
    await _guard(() => windowManager.setFullScreen(true));
  } else {
    await _guard(
      () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }
}

Future<void> exitSignMode() async {
  await _guard(() => WakelockPlus.disable());
  if (isDesktop) {
    await _guard(() => windowManager.setFullScreen(false));
  } else {
    await _guard(
      () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    );
  }
}

/// Screen-mode changes are cosmetic; never let a platform hiccup crash the app.
Future<void> _guard(Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    debugPrint('Screen mode change failed: $e');
  }
}
