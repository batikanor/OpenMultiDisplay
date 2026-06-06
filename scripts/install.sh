#!/bin/bash
set -e

# Navigate to project root (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "Installing TetherSpan..."
echo ""

# Prefer Homebrew OpenJDK, then Android Studio's bundled JDK, then caller-provided JAVA_HOME.
if [ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
elif [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
elif [ -z "${JAVA_HOME:-}" ] || [ ! -d "$JAVA_HOME" ]; then
    echo "Java not found. Install OpenJDK 17 or Android Studio, or set JAVA_HOME manually."
    exit 1
fi

export PATH="$JAVA_HOME/bin:$PATH"

if [ -d "/opt/homebrew/share/android-commandlinetools" ]; then
    export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
    export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
fi

# Check ADB connection first
echo "📱 Checking ADB connection..."
DEVICES=$(adb devices | awk '/\tdevice$/ {print $1}')
if [ -z "$DEVICES" ]; then
    echo "❌ No Android device found via ADB"
    echo "   Please connect your device via USB and enable USB debugging"
    exit 1
fi
echo "  ✓ Android device(s) connected:"
printf '    %s\n' $DEVICES
echo ""

# Build macOS app
echo "📦 Building macOS app..."
cd MacHost
swift build -c release
cd "$ROOT_DIR"
echo "  ✓ macOS app built"

# Create macOS .app bundle
echo "📦 Creating macOS .app bundle..."
APP_NAME="TetherSpan.app"
APP_DIR="$APP_NAME/Contents"
rm -rf "$APP_NAME"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy executable
cp MacHost/.build/release/TetherSpan "$APP_DIR/MacOS/TetherSpan"

# Create Info.plist
cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>TetherSpan</string>
    <key>CFBundleDisplayName</key>
    <string>TetherSpan</string>
    <key>CFBundleIdentifier</key>
    <string>com.batikanor.tetherspan</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>TetherSpan</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

echo "  ✓ macOS .app bundle created: $APP_NAME"
echo ""

# Build Android app
echo "📦 Building Android app..."
cd AndroidClient
./gradlew assembleDebug
cd "$ROOT_DIR"
echo "  ✓ Android app built"
echo ""

# Install Android app
echo "📱 Installing Android app..."
for serial in $DEVICES; do
    adb -s "$serial" install -r AndroidClient/app/build/outputs/apk/debug/app-debug.apk
done
echo "  ✓ Android app installed"
echo ""

# Setup ADB reverse (with retry)
echo "🔧 Setting up USB port forwarding..."
for serial in $DEVICES; do
    adb -s "$serial" reverse --remove tcp:54321 2>/dev/null || true
done
sleep 0.5
for serial in $DEVICES; do
    adb -s "$serial" reverse tcp:54321 tcp:54321
done

# Verify ADB reverse is active
echo "🔍 Verifying port forwarding..."
OK=true
for serial in $DEVICES; do
    if ! adb -s "$serial" reverse --list | grep -q "tcp:54321"; then
        OK=false
    fi
done

if [ "$OK" = true ]; then
    echo "  ✓ Port 54321 forwarded successfully"
else
    echo "  ⚠️  Port forwarding setup but verification failed"
    echo "  Run './scripts/setup-usb.sh' if connection issues occur"
fi
echo ""

echo "✅ Installation complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "To start streaming:"
echo "  1. Start Mac app: open 'TetherSpan.app'"
echo "     (or run: MacHost/.build/release/TetherSpan)"
echo "  2. Open 'TetherSpan' app on Android"
echo "  3. Tap Connect"
echo ""
echo "💡 Troubleshooting:"
echo "  • Connection fails: ./scripts/setup-usb.sh"
echo "  • Check server: lsof -i :54321"
echo "  • Check forwarding: adb reverse --list"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
