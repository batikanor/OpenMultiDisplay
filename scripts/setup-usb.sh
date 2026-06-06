#!/bin/bash
set -e

echo "Setting up USB port forwarding..."

# Check ADB connection
DEVICES=$(adb devices | awk '/\tdevice$/ {print $1}')
if [ -z "$DEVICES" ]; then
    echo "❌ No Android device found via ADB"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Connect device via USB cable"
    echo "  2. Enable Developer Options on device"
    echo "  3. Enable USB Debugging in Developer Options"
    echo "  4. Accept the USB debugging prompt on device"
    echo "  5. Run this script again"
    exit 1
fi

echo "  Device(s) connected:"
printf '    %s\n' $DEVICES

# Remove existing reverse
echo "  Clearing existing port forwards..."
for serial in $DEVICES; do
    adb -s "$serial" reverse --remove-all 2>/dev/null || true
done
sleep 0.5

# Setup new reverse
echo "  Setting up port 54321..."
for serial in $DEVICES; do
    adb -s "$serial" reverse tcp:54321 tcp:54321
done

# Verify
OK=true
for serial in $DEVICES; do
    if ! adb -s "$serial" reverse --list | grep -q "tcp:54321"; then
        OK=false
    fi
done

if [ "$OK" = true ]; then
    echo ""
    echo "USB port forwarding active."
    echo ""
    adb reverse --list
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ready to connect. Make sure Mac app is running."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    echo "Port forwarding failed"
    exit 1
fi
