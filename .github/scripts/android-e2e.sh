#!/usr/bin/env bash
#
# Runs inside reactivecircus/android-emulator-runner with the emulator already
# booted, cwd = frontend/. Two stages, both fatal:
#
#   1. Scripted E2E -- integration_test/e2e_test.dart (E2E-1/2/3) driven on the
#      emulator against the live backend on the host.
#   2. Monkey crawl -- a Test Lab Robo-style pseudo-random pass over the
#      installed release APK, to catch crashes on screens the scripted flows
#      never visit.
#
# Runnable locally too: boot any emulator, start the backend on :8000, then
#   cd frontend && bash ../.github/scripts/android-e2e.sh
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://10.0.2.2:8000}"
PACKAGE="com.builderplaza.builder_plaza"
LOG_DIR="build/e2e-logs"
# Fixed seed so a crawl failure is reproducible instead of a one-off.
MONKEY_SEED="${MONKEY_SEED:-20260723}"
MONKEY_EVENTS="${MONKEY_EVENTS:-1500}"

mkdir -p "$LOG_DIR"
adb wait-for-device
DEVICE="$(adb devices | awk '/device$/ {print $1; exit}')"
echo "==> emulator: $DEVICE, backend: $API_BASE_URL"

# The app talks to the host over cleartext; that is allowed for 10.0.2.2 by
# android/app/src/main/res/xml/network_security_config.xml.
echo "==> stage 1/2: scripted E2E flows"
flutter test integration_test \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  -d "$DEVICE" \
  2>&1 | tee "$LOG_DIR/e2e.log"

echo "==> stage 2/2: Monkey crawl"
flutter build apk --release --dart-define=API_BASE_URL="$API_BASE_URL"
adb install -r -t build/app/outputs/flutter-apk/app-release.apk
adb logcat -c

# --pct-syskeys/--pct-anyevent 0 keeps the crawl inside the app instead of
# wandering into the launcher; --ignore-timeouts would hide ANRs, so it is off.
set +e
adb shell monkey -p "$PACKAGE" \
  -s "$MONKEY_SEED" \
  --throttle 200 \
  --pct-syskeys 0 \
  --pct-anyevent 0 \
  --monitor-native-crashes \
  -v -v "$MONKEY_EVENTS" 2>&1 | tee "$LOG_DIR/monkey.log"
monkey_status=${PIPESTATUS[0]}
set -e

adb logcat -d > "$LOG_DIR/logcat.txt"

# Monkey's exit status alone is not trustworthy across API levels, so assert on
# what it actually reported plus any fatal in our own process.
if [ "$monkey_status" -ne 0 ] \
  || grep -qE '// (CRASH|NOT RESPONDING)' "$LOG_DIR/monkey.log" \
  || grep -q "FATAL EXCEPTION" "$LOG_DIR/logcat.txt"; then
  echo "!!! Monkey crawl found a crash or ANR -- see $LOG_DIR/"
  grep -E '// (CRASH|NOT RESPONDING)' -A 20 "$LOG_DIR/monkey.log" || true
  grep "FATAL EXCEPTION" -A 30 "$LOG_DIR/logcat.txt" || true
  exit 1
fi

echo "==> both stages passed ($MONKEY_EVENTS events, seed $MONKEY_SEED)"
