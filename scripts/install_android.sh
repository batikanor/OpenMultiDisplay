#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APK_PATH="$ROOT_DIR/AndroidClient/app/build/outputs/apk/debug/app-debug.apk"

echo "📱 Installing Android app..."

# Check if APK exists
if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK not found. Building first..."
    "$SCRIPT_DIR/build_android.sh"
fi

# Check ADB connection
DEVICES=$(adb devices | awk '/\tdevice$/ {print $1}')
if [ -z "$DEVICES" ]; then
    echo "❌ No Android device found via ADB"
    echo "   Please connect your device via USB and enable USB debugging"
    exit 1
fi

# Install APK
for serial in $DEVICES; do
    echo "Installing on $serial..."
    adb -s "$serial" install -r "$APK_PATH"
done

echo ""
echo "✅ App installed successfully!"
echo ""
echo "📲 Setting up USB port forwarding..."
for serial in $DEVICES; do
    adb -s "$serial" reverse --remove tcp:54321 2>/dev/null || true
    adb -s "$serial" reverse tcp:54321 tcp:54321
done

echo "✅ Port 54321 forwarded"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ready! Open 'TetherSpan' on your Android device"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
