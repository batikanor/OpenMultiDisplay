#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[1/6] Checking whitespace"
cd "$ROOT_DIR"
git diff --check

echo "[2/6] Validating website"
node scripts/validate_website.mjs

echo "[3/6] Testing macOS"
cd "$ROOT_DIR/MacHost"
swift test
swift build

echo "[4/6] Selecting Android toolchain"
if [ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
elif [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
elif [ -z "${JAVA_HOME:-}" ] || [ ! -d "$JAVA_HOME" ]; then
  echo "JAVA_HOME is not set and OpenJDK 17 was not found."
  exit 1
fi
export PATH="$JAVA_HOME/bin:$PATH"

if [ -d "$HOME/.local/android/platforms/android-34" ]; then
  export ANDROID_HOME="$HOME/.local/android"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
elif [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/platforms/android-34" ]; then
  export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
elif [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "$ANDROID_SDK_ROOT/platforms/android-34" ]; then
  export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
else
  echo "Android SDK API 34 not found. Install it with sdkmanager before running full validation."
  exit 1
fi

echo "[5/6] Testing Android"
cd "$ROOT_DIR/AndroidClient"
chmod +x gradlew
./gradlew testDebugUnitTest lintDebug assembleDebug

echo "[6/6] Running ktlint"
if command -v ktlint >/dev/null 2>&1; then
  ktlint "app/src/main/java/**/*.kt" "app/src/test/java/**/*.kt"
else
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  curl -fL --retry 3 --retry-delay 2 -o "$tmpdir/ktlint" https://github.com/pinterest/ktlint/releases/download/1.1.1/ktlint
  chmod +x "$tmpdir/ktlint"
  "$tmpdir/ktlint" "app/src/main/java/**/*.kt" "app/src/test/java/**/*.kt"
fi

echo "All validation checks passed."
