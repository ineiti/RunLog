#!/usr/bin/env bash
# Usage: install.sh [adb install flags...]
# Builds a release (non-debug) APK with version info baked in, then installs
# it onto a connected Android device, updating any existing install in place
# (adb install -r) so app data on the device is preserved.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/build_env.sh

# Locate adb from the global Android SDK install (not a devbox package,
# since android-tools is large and shared across multiple mobile projects).
: "${ANDROID_HOME:="${ANDROID_SDK_ROOT:-}"}"
if [ -z "$ANDROID_HOME" ] && [ -f android/local.properties ]; then
  ANDROID_HOME="$(sed -n 's/^sdk.dir=//p' android/local.properties)"
fi
ADB="${ANDROID_HOME:+$ANDROID_HOME/platform-tools/adb}"
if [ -z "${ADB:-}" ] || [ ! -x "$ADB" ]; then
  ADB="$(command -v adb || true)"
fi
if [ -z "$ADB" ]; then
  echo "error: could not find adb (checked ANDROID_HOME/ANDROID_SDK_ROOT, android/local.properties, and PATH)" >&2
  exit 1
fi

flutter build apk --release "${DART_DEFINES[@]}"
"$ADB" install -r "$@" build/app/outputs/flutter-apk/app-release.apk
