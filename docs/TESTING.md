# Testing and Verification

OpenMultiDisplay uses unit tests, CI matrix builds, static checks, and targeted physical-device validation. The project deliberately separates automated proof from hardware proof because GitHub-hosted runners cannot attach Android devices over USB.

## Automated CI

| Workflow | Platform | Checks |
| --- | --- | --- |
| Build macOS | `macos-14`, `macos-15`, `macos-15-intel`, `macos-26`, `macos-26-intel` | `swift test`, release arm64 build, release x86_64 build, universal binary creation, SwiftLint strict mode. |
| Build Android | `ubuntu-latest` with JDK 17 | `testDebugUnitTest`, `lintDebug`, `assembleDebug`, ktlint over main and test Kotlin sources. |
| Release | Tag-triggered macOS and Android artifact build | macOS tests, universal `.app`/DMG build, Android tests, release APK build. |

The macOS runner labels come from GitHub's official hosted-runner table. The Android API floor is `minSdk = 26`, and Android's official API-level table maps API 26 to Android 8.0.

## Local Validation Commands

Run these before opening a pull request:

```bash
cd MacHost
swift test
swift build
```

```bash
cd AndroidClient
./gradlew testDebugUnitTest lintDebug assembleDebug
```

The Android command requires a valid local Android SDK through `ANDROID_HOME`, `ANDROID_SDK_ROOT`, or `AndroidClient/local.properties`. If the local shell has no SDK selected, use the Android GitHub Actions workflow as the SDK-backed validation source.

```bash
git diff --check
```

Optional local Kotlin style check:

```bash
cd AndroidClient
ktlint "app/src/main/java/**/*.kt" "app/src/test/java/**/*.kt"
```

## Current Unit Coverage

| Area | Test files |
| --- | --- |
| macOS device profiles and USB lifecycle | `DeviceDisplayConfigStoreTests.swift`, `USBPipelineReconcilerTests.swift` |
| macOS protocol and auth | `WireCodecTests.swift`, `HandshakeCodecTests.swift`, `WirelessAuthTests.swift`, `PairingURLTests.swift` |
| macOS networking helpers | `LANAddressResolverTests.swift`, `PairedDeviceStoreTests.swift` |
| Android protocol and receiver logic | `WireProtocolTest.kt`, `AuthHandshakeTest.kt`, `ConnectionModeTest.kt`, `InputPredictorTest.kt`, `PairingURLTest.kt` |

## Physical Hardware Validation

Last physical validation: June 6, 2026.

| Host | OS | Android receivers | Result |
| --- | --- | --- | --- |
| MacBook Pro `Mac16,8`, Apple M4 Pro, 48 GB RAM | macOS 26.5.1 build 25F80 | Galaxy Tab S7 + Galaxy Z Fold 4 over USB | Two independent macOS displays streamed at the same time. |

Disconnect behavior was validated at the unit level through `USBPipelineReconcilerTests.swift`. In real hardware use, unplugging one USB device should remove only that device's virtual display while the other USB display remains active.

## What Is Not Proven Yet

- Long-duration soak testing across many hours.
- Physical testing on MacBook Air, Intel MacBook Pro, MacBook Neo, or non-Samsung Android receivers.
- Signed/notarized production distribution.
- Performance guarantees for every supported resolution, refresh rate, or receiver decoder.

Those are tracked in [ROADMAP.md](ROADMAP.md).
