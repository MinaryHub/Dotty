#!/usr/bin/env bash
# Builds the Flutter web app on Vercel, whose build image has no Flutter SDK.
# Used as the Vercel build command (see vercel.json); also works locally.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.8}"
FLUTTER_HOME="${FLUTTER_HOME:-$PWD/.flutter-sdk}"

if ! command -v unzip >/dev/null 2>&1; then
  # Flutter needs unzip to unpack the Dart SDK; Vercel's image uses dnf.
  dnf install -y unzip
fi

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION into $FLUTTER_HOME"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
flutter config --no-analytics --enable-web >/dev/null
flutter --version
flutter pub get
# Serve CanvasKit from our own deployment instead of Google's CDN.
flutter build web --release --no-web-resources-cdn
