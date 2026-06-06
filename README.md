# SideScreen Multi

SideScreen Multi is an MIT-licensed fork of [SideScreen](https://github.com/tranvuongquocdat/SideScreen) focused on making Android phones and tablets useful as USB-connected macOS displays.

The immediate target is a MacBook with more than one Android receiver attached at the same time, for example a Galaxy Tab plus a Galaxy Z Fold.

## Status

This repository is early alpha.

What works in this fork:

- macOS host builds on macOS 14+ with Swift Package Manager.
- Android client keeps the upstream USB and wireless receiver flow.
- USB setup now targets every authorized Android device by ADB serial.
- The Mac streaming server no longer evicts the first receiver when another receiver connects.
- Multiple Android clients can receive the same virtual display stream concurrently.

What is still in progress:

- Independent virtual displays per Android device.
- Per-device resolution, rotation, bitrate, and touch routing.
- Release signing, notarization, and production packaging.
- End-to-end validation with two physical Android devices.

## Why This Fork Exists

Upstream SideScreen is designed around one active Android receiver. That is enough for a tablet-as-monitor workflow, but it does not cover multi-device desk setups. SideScreen Multi keeps the upstream foundation and extends it toward multi-receiver USB operation.

## Requirements

| Component | Requirement |
| --- | --- |
| macOS host | macOS 14 Sonoma or newer |
| Android receiver | Android 8.0 or newer with H.265 hardware decode |
| USB mode | Android platform-tools / `adb`, USB debugging enabled |
| Build tools | Swift 5.9+, Xcode command line tools, Android Studio or JDK/Android SDK |

## Build

macOS host:

```bash
cd MacHost
swift build
```

Android receiver:

```bash
cd AndroidClient
./gradlew assembleDebug
```

Helper scripts are available under `scripts/`, but the Swift and Gradle commands above are the canonical development entry points.

## USB Development Flow

1. Enable Developer Options and USB debugging on each Android device.
2. Connect the devices by USB.
3. Confirm every device is authorized:

```bash
adb devices -l
```

4. Build and start the Mac host.
5. Open SideScreen Multi on each Android device and use the USB tab.

The Mac host configures:

```bash
adb -s <serial> reverse tcp:54321 tcp:54321
```

for each authorized Android device.

## Architecture

The fork currently has one virtual macOS display and one encoder feeding multiple receiver connections. That is useful for proving stable multi-client transport, but it mirrors the same desktop to every receiver.

The planned architecture is one pipeline per Android device:

```text
Android device A -> ADB reverse port A -> virtual display A -> capture A -> encoder A
Android device B -> ADB reverse port B -> virtual display B -> capture B -> encoder B
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/ROADMAP.md](docs/ROADMAP.md).

## Attribution

SideScreen Multi is derived from SideScreen by Trần Vương Quốc Đạt and contributors. The original project is MIT licensed. The original copyright notice is preserved in [LICENSE](LICENSE), and fork-specific attribution is documented in [NOTICE](NOTICE).

Core contributor for this fork:

- Batikan Orpava `<batikanor@gmail.com>`

## License

MIT. See [LICENSE](LICENSE).
