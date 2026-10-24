import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> requestBrowserFullscreen() async {
  if (web.document.fullscreenElement != null) return;
  await web.document.documentElement?.requestFullscreen().toDart;
}

Future<void> exitBrowserFullscreen() async {
  if (web.document.fullscreenElement == null) return;
  await web.document.exitFullscreen().toDart;
}
