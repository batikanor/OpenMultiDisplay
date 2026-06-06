#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Starting OpenMultiDisplay..."

# Kill any existing instance
pkill -f OpenMultiDisplay 2>/dev/null || true
sleep 0.3

# Check if app bundle exists
if [ -d "$ROOT_DIR/OpenMultiDisplay.app" ]; then
    echo "  Opening OpenMultiDisplay.app..."
    open "$ROOT_DIR/OpenMultiDisplay.app"
elif [ -f "$ROOT_DIR/MacHost/.build/release/OpenMultiDisplay" ]; then
    echo "  Running release binary..."
    "$ROOT_DIR/MacHost/.build/release/OpenMultiDisplay" &
elif [ -f "$ROOT_DIR/MacHost/.build/debug/OpenMultiDisplay" ]; then
    echo "  Running debug binary..."
    "$ROOT_DIR/MacHost/.build/debug/OpenMultiDisplay" &
else
    echo "❌ No build found. Building now..."
    "$SCRIPT_DIR/build_mac.sh"
    echo ""
    echo "  Opening OpenMultiDisplay.app..."
    open "$ROOT_DIR/OpenMultiDisplay.app"
fi

echo ""
echo "✅ Mac app started!"
echo ""

# Setup USB if device connected
if command -v adb >/dev/null 2>&1 && adb devices 2>/dev/null | grep -q "device$"; then
    echo "Android device detected. The Mac app will set up USB forwarding on port 54321."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Open 'OpenMultiDisplay' on Android and tap Connect"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
