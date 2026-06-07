#!/bin/bash
set -e

# Get absolute path to root directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/scripts/lib/signing.sh"

# Read version
VERSION=$(cat "$ROOT_DIR/VERSION" | tr -d '[:space:]')
ANDROID_APK_SRC="$ROOT_DIR/AndroidClient/app/build/outputs/apk/debug/app-debug.apk"
ANDROID_APK_BUNDLED_NAME="OpenMultiDisplay-android.apk"
echo "Building version $VERSION..."

echo "Building Android receiver APK..."
if [ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
elif [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

if [ -n "${JAVA_HOME:-}" ] && [ -d "$JAVA_HOME" ]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if [ -d "/opt/homebrew/share/android-commandlinetools" ]; then
  export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
  export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
fi

if [ -x "$ROOT_DIR/AndroidClient/gradlew" ] && command -v java >/dev/null 2>&1; then
  (cd "$ROOT_DIR/AndroidClient" && ./gradlew assembleDebug)
else
  echo "  Android toolchain not available; using existing APK if present"
fi

cd "$ROOT_DIR/MacHost"

# Kill running instance
echo "Stopping running OpenMultiDisplay..."
pkill -f OpenMultiDisplay 2>/dev/null || true
sleep 0.5

# Clean old build
echo "Cleaning old build..."
rm -rf .build

# Build fresh (Universal Binary: arm64 + x86_64)
echo "Building macOS Host (arm64)..."
swift build -c release --arch arm64

echo "Building macOS Host (x86_64)..."
swift build -c release --arch x86_64

echo "Creating Universal Binary..."
mkdir -p ".build/release-universal"
lipo -create \
  .build/arm64-apple-macosx/release/OpenMultiDisplay \
  .build/x86_64-apple-macosx/release/OpenMultiDisplay \
  -output .build/release-universal/OpenMultiDisplay

# Create .app bundle
APP_NAME="OpenMultiDisplay"
APP_DIR="$ROOT_DIR/$APP_NAME.app"

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy universal binary
cp .build/release-universal/OpenMultiDisplay "$APP_DIR/Contents/MacOS/"

# Copy app icon if exists
if [ -f "$ROOT_DIR/MacHost/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/MacHost/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
    echo "  ✓ App icon copied"
fi

if [ -f "$ANDROID_APK_SRC" ]; then
    mkdir -p "$APP_DIR/Contents/Resources/Android"
    cp "$ANDROID_APK_SRC" "$APP_DIR/Contents/Resources/Android/$ANDROID_APK_BUNDLED_NAME"
    echo "  ✓ Android receiver APK bundled"
else
    echo "  ⚠ Android receiver APK not found; desktop app will show APK as missing"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OpenMultiDisplay</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.batikanor.openmultidisplay</string>
    <key>CFBundleName</key>
    <string>OpenMultiDisplay</string>
    <key>CFBundleDisplayName</key>
    <string>OpenMultiDisplay</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string><!-- VERSION -->
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string><!-- VERSION -->
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>OpenMultiDisplay needs screen recording access to capture your virtual display and stream it to your Android device.</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>OpenMultiDisplay needs Local Network access so your Android tablet can connect to the Mac over WiFi for wireless mode. Without this, only USB-tethered connections work.</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_openmultidisplay._tcp</string>
    </array>
</dict>
</plist>
EOF

openmultidisplay_sign_app "$APP_DIR" "$ROOT_DIR/MacHost/OpenMultiDisplay.entitlements"
echo "  ✓ App signed"

echo ""
echo "Build successful!"
echo ""
echo "App: $ROOT_DIR/$APP_NAME.app"
echo "To run: open \"$APP_NAME.app\""

# Create DMG with Applications symlink
echo ""
echo "Creating DMG..."
DMG_DIR=$(mktemp -d)
cp -R "$APP_DIR" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
DMG_PATH="$ROOT_DIR/OpenMultiDisplay-${VERSION}-mac-universal.dmg"
hdiutil create -volname "OpenMultiDisplay" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_DIR"
echo "DMG: $DMG_PATH"
