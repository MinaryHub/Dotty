import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'browser_fullscreen.dart';

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
/// (desktop), browser fullscreen (web) or immersive system UI (Android), with
/// the screen kept awake.
///
/// On the web, call this directly from the click handler: browsers only grant
/// fullscreen during the user's gesture, so it is requested before anything
/// else is awaited.
Future<void> enterSignMode() async {
  final Future<void> screen;
  if (kIsWeb) {
    screen = _guard(requestBrowserFullscreen);
  } else if (isDesktop) {
    screen = _guard(() => windowManager.setFullScreen(true));
  } else {
    screen = _guard(
      () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }
  await _guard(() => WakelockPlus.enable());
  await screen;
}

Future<void> exitSignMode() async {
  await _guard(() => WakelockPlus.disable());
  if (kIsWeb) {
    await _guard(exitBrowserFullscreen);
  } else if (isDesktop) {
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
