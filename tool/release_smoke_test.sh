#!/usr/bin/env bash
# Installs a release APK on the running emulator, opens it, and fails if the
# app crashes or closes. Release builds are shrunk by R8 and can crash in ways
# debug builds never do (v1.0.0 was rejected by Play for exactly that).
#
#   bash tool/release_smoke_test.sh build/app/outputs/flutter-apk/app-prod-release.apk
set -euo pipefail

apk="$1"
pkg="pk.salelagihai.app"
wait_seconds="${SMOKE_WAIT_SECONDS:-30}"

adb install -r "$apk"
adb logcat -b all -c
adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 > /dev/null
sleep "$wait_seconds"

crash="$(adb logcat -d -b crash | grep -A60 "Process: $pkg" || true)"
if [ -n "$crash" ] || ! adb shell pidof "$pkg" > /dev/null; then
  echo "::error::$pkg crashed or closed within ${wait_seconds}s of launch"
  echo "$crash"
  adb logcat -d -t 400 | grep -iE "AndroidRuntime|flutter|$pkg" || true
  exit 1
fi

# Back to the home screen and in again: the app must survive a restart too.
adb shell input keyevent KEYCODE_HOME
adb shell am force-stop "$pkg"
adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 > /dev/null
sleep 15
if [ -n "$(adb logcat -d -b crash | grep "Process: $pkg" || true)" ] \
  || ! adb shell pidof "$pkg" > /dev/null; then
  echo "::error::$pkg crashed on the second launch"
  adb logcat -d -b crash
  exit 1
fi

echo "OK: $pkg opened twice and was still running, with no crash."
