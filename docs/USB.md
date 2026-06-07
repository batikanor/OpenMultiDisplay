# USB Operation

USB mode is the primary OpenMultiDisplay path. It lets multiple Android devices connect to the Mac at the same time while each device receives a separate macOS virtual display.

## Setup

1. Enable Developer Options and USB debugging on each Android device.
2. Install the OpenMultiDisplay Android receiver APK on each device. The macOS
   app's Android Receiver panel can reveal the APK, show whether each connected
   device already has the receiver installed, and install or launch it over USB
   when ADB sees authorized devices.
3. Connect each Android device to the Mac by USB.
4. Confirm every device is listed as `device`, not `unauthorized`:

```bash
adb devices -l
```

5. Start the macOS host.
6. Launch the Android receiver on each device and use the USB tab.

## Port Mapping

Android always connects to `127.0.0.1:54321` in USB mode. The Mac assigns a unique host port to each physical device and configures ADB reverse by serial:

```bash
adb -s <serial-a> reverse tcp:54321 tcp:54321
adb -s <serial-b> reverse tcp:54321 tcp:54322
```

The Android `adb reverse` command forwards a port on the device to a different port on the host. OpenMultiDisplay relies on the `-s <serial>` selector so two physical devices can use the same Android-side port without colliding.

## Display Profiles

Per-device USB profiles live at:

```text
~/.openmultidisplay/devices.json
```

Each key is an ADB serial. Example:

```json
{
  "devices": {
    "R52N718E7NY": {
      "name": "Galaxy Tab S7",
      "width": 1920,
      "height": 1200,
      "refreshRate": 60,
      "bitrate": 1000,
      "quality": "ultralow",
      "hiDPI": false,
      "rotation": 0,
      "positionX": 1440,
      "positionY": 0
    }
  }
}
```

If the file does not exist, the Mac host writes starter profiles for connected devices on first USB start. The app UI can then edit the profile for each connected device.

## Disconnect Behavior

The host refreshes ADB device status periodically. When one USB receiver disappears from the authorized-device list, OpenMultiDisplay stops only that receiver's `DisplayPipeline`, removes its virtual display, and leaves the remaining receiver pipelines running.

If every USB receiver disappears, the host stops the USB session and reports that no USB displays are connected.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Device does not appear | Run `adb devices -l`; reconnect USB; accept the USB debugging prompt on Android. |
| Android receiver is missing or old | Use the desktop app's Android Receiver panel; it shows per-device receiver state and can install missing or stale APKs. |
| Receiver is installed but closed | Use **Install Missing & Run** in the Android Receiver panel to launch it from the Mac. |
| Android says USB connected but no image appears | Restart USB mode after confirming `adb reverse` was configured for that serial. |
| Two devices show the same display | Make sure the host build is OpenMultiDisplay and not upstream SideScreen; USB mode should create one `DisplayPipeline` per serial. |
| Wrong size or orientation | Edit the device profile in the app or in `~/.openmultidisplay/devices.json`, then restart USB mode. |
| One unplugged device leaves a stale display | Wait for the next status refresh; the matching serial should be reconciled and removed. |
