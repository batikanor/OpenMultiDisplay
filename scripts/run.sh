#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Starting TetherSpan..."

# Kill any existing instance
pkill -f TetherSpan 2>/dev/null || true
sleep 0.3

# Check if app bundle exists
if [ -d "$ROOT_DIR/TetherSpan.app" ]; then
    echo "  Opening TetherSpan.app..."
    open "$ROOT_DIR/TetherSpan.app"
elif [ -f "$ROOT_DIR/MacHost/.build/release/TetherSpan" ]; then
    echo "  Running release binary..."
    "$ROOT_DIR/MacHost/.build/release/TetherSpan" &
elif [ -f "$ROOT_DIR/MacHost/.build/debug/TetherSpan" ]; then
    echo "  Running debug binary..."
    "$ROOT_DIR/MacHost/.build/debug/TetherSpan" &
else
    echo "❌ No build found. Building now..."
    "$SCRIPT_DIR/build_mac.sh"
    echo ""
    echo "  Opening TetherSpan.app..."
    open "$ROOT_DIR/TetherSpan.app"
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
echo "Open 'TetherSpan' on Android and tap Connect"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
