# OpenMultiDisplay

OpenMultiDisplay is an MIT-licensed fork of [SideScreen](https://github.com/tranvuongquocdat/SideScreen) that turns Android phones and tablets into USB-connected macOS displays.

The fork is focused on true multi-device extended displays: one virtual macOS display, stream, encoder, and ADB reverse tunnel per Android device.

## Status

This repository is early alpha, but the USB multi-display path is working on the development hardware.

| Area | Current state |
| --- | --- |
| USB multi-display | Working with two authorized Android devices at once. |
| Independent displays | Each USB receiver gets its own virtual display and Mac-side stream. |
| Per-device controls | Profiles can set resolution, refresh rate, bitrate, quality, HiDPI, rotation, and arrangement position by ADB serial. |
| Wireless mode | Kept from upstream as the single-display path. |
| Packaging | App identity is separate from upstream SideScreen; production signing and notarization are still pending. |

## Requirements

| Component | Requirement |
| --- | --- |
| macOS host | macOS 14 Sonoma or newer |
| Android receiver | Android 8.0 / API 26 or newer |
| USB mode | Android platform-tools / `adb`, USB debugging enabled, authorized device |
| Video decode | H.265 / HEVC decode support on the Android receiver |
| Build tools | Xcode command line tools, Swift, Android Studio or Android SDK/JDK |

Detailed compatibility, official references, and the development system specs are in [docs/SUPPORT.md](docs/SUPPORT.md).

## Build

macOS host:

```bash
cd MacHost
swift test
swift build
```

Android receiver:

```bash
cd AndroidClient
./gradlew testDebugUnitTest lintDebug assembleDebug
```

## Android Receiver APK

Android phones and tablets need the OpenMultiDisplay receiver APK installed before
they can connect. The macOS app includes an **Android Receiver** panel that shows
whether an APK is available, reveals it in Finder, tracks receiver install and
running state for each authorized USB device, and can install missing or stale
receivers before launching them with ADB.

For release users, download the macOS DMG and Android APK from the same release.
For local development, build the APK with:

```bash
./scripts/build_android.sh
```

## Project Docs

| Document | Purpose |
| --- | --- |
| [docs/USB.md](docs/USB.md) | USB setup, ADB reverse mapping, device profiles, disconnect behavior, troubleshooting. |
| [docs/SUPPORT.md](docs/SUPPORT.md) | MacBook Air/Pro/Neo support matrix, Android requirements, official citations, development machine specs. |
| [docs/TESTING.md](docs/TESTING.md) | Automated CI matrix, local validation commands, physical hardware validation, remaining gaps. |
| [docs/CODE_STYLE.md](docs/CODE_STYLE.md) | Swift/Kotlin style rules, reference projects, testing expectations, documentation standards. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Host/client pipeline structure and design constraints. |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Product-quality milestones and remaining work. |

## Attribution

OpenMultiDisplay is derived from SideScreen by Trần Vương Quốc Đạt and contributors. The original project is MIT licensed. The original copyright notice is preserved in [LICENSE](LICENSE), and fork-specific attribution is documented in [NOTICE](NOTICE).

Core contributors for this fork:

- Batikan Orpava `<batikanor@gmail.com>`
- `m2moiz`

## License

MIT. See [LICENSE](LICENSE).
