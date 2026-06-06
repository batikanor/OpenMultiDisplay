# Support Matrix

OpenMultiDisplay is a macOS 14+ host application with an Android receiver. The host is built as a universal Swift executable for Apple silicon and Intel, but support claims are split into three proof levels:

| Proof level | Meaning |
| --- | --- |
| Official OS eligibility | The laptop model appears in Apple's compatibility list for macOS 14 Sonoma, macOS 15 Sequoia, or macOS 26 Tahoe. |
| CI validation | GitHub Actions builds and tests the project on the listed macOS runner label. |
| Physical validation | The host streamed real USB displays on the local development hardware listed below. |

Sources checked on June 6, 2026:

- Apple: [macOS Sonoma compatibility](https://support.apple.com/en-us/105113).
- Apple: [macOS Sequoia compatibility](https://support.apple.com/en-us/120282).
- Apple: [macOS Tahoe compatibility](https://support.apple.com/en-us/122867).
- GitHub: [GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
- Android: [`<uses-sdk>` and API levels](https://developer.android.com/guide/topics/manifest/uses-sdk-element).
- Android: [Android Debug Bridge](https://developer.android.com/tools/adb).
- Android: [Supported media formats](https://developer.android.com/media/platform/supported-formats).

## Mac Laptop Support

OpenMultiDisplay treats a Mac laptop as eligible when it can run macOS 14 or newer according to Apple, has Screen Recording permission for the host app, and has enough CPU/GPU headroom for one capture/encode pipeline per Android receiver.

| Laptop family | macOS 14 Sonoma | macOS 15 Sequoia | macOS 26 Tahoe | OpenMultiDisplay status |
| --- | --- | --- | --- | --- |
| MacBook Pro | Apple lists 2018 and later MacBook Pro models, including the 2018 13-inch/15-inch models through 2023 models. | Apple lists 2018 and later MacBook Pro models, adding the 2024 14-inch/16-inch models. | Apple lists MacBook Pro (14-inch, M5), 2024 14-inch/16-inch, 2023 14-inch/16-inch, 13-inch M2 2022, 2021 14-inch/16-inch, 13-inch M1 2020, 13-inch 2020 with Four Thunderbolt 3 ports, and 16-inch 2019. | Eligible on the listed Apple-supported OS versions. Physically validated on MacBook Pro `Mac16,8` with Apple M4 Pro. |
| MacBook Air | Apple lists MacBook Air 2018 and later, including Retina 13-inch 2018/2019/2020, M1 2020, M2 2022, 15-inch M2 2023, and 13-inch/15-inch M3 2024. | Apple lists MacBook Air Retina 13-inch 2020 and later, including M1 2020, M2 2022/2023, M3 2024, and M4 2025 models. | Apple lists Apple-silicon MacBook Air models: M1 2020, M2 2022, 15-inch M2 2023, M3 2024, and M4 2025. | Eligible on the listed Apple-supported OS versions. Not physically tested yet in this repository. |
| MacBook Neo | Not listed by Apple for Sonoma. | Not listed by Apple for Sequoia. | Apple lists MacBook Neo (13-inch, A18 Pro). | Eligible only on Tahoe by Apple's current list. Not physically tested yet in this repository. |
| 12-inch MacBook | Not listed by Apple for Sonoma. | Not listed by Apple for Sequoia. | Not listed by Apple for Tahoe. | Not supported because it cannot run the project's macOS 14+ host target through Apple's official compatibility path. |

## CI-Covered macOS Hosts

The macOS CI matrix uses GitHub's official standard hosted runner labels:

| Runner label | OS family | CPU architecture | What it proves |
| --- | --- | --- | --- |
| `macos-14` | macOS 14 | Apple silicon arm64 | Swift tests, release build, and lint pass on Sonoma-era arm64 runner. |
| `macos-15` | macOS 15 | Apple silicon arm64 | Swift tests, release build, and lint pass on Sequoia-era arm64 runner. |
| `macos-15-intel` | macOS 15 | Intel x64 | Swift tests, release build, and lint pass on an Intel macOS runner. |
| `macos-26` | macOS 26 | Apple silicon arm64 | Swift tests, release build, and lint pass on Tahoe-era arm64 runner. |
| `macos-26-intel` | macOS 26 | Intel x64 | Swift tests, release build, and lint pass on an Intel Tahoe runner. |

CI cannot prove physical USB behavior because GitHub-hosted runners do not attach Android devices. Physical USB validation is listed separately below.

## Android Receiver Support

| Requirement | Reason |
| --- | --- |
| Android 8.0 / API 26 or newer | The Gradle project sets `minSdk = 26`; Android's API-level documentation maps API 26 to Android 8.0. |
| Authorized USB debugging | USB mode uses ADB and `adb reverse` per Android serial. |
| H.265 / HEVC decode | The host streams H.265 video. Android's media documentation lists HEVC as a supported media format, but device performance still depends on the receiver's codec implementation. |
| Enough display/decode performance | Higher resolution, HiDPI, refresh rate, and bitrate increase decode load and USB bandwidth. |

## Development System

Captured from the development machine on June 6, 2026:

| Component | Value |
| --- | --- |
| Mac model | MacBook Pro |
| Model identifier | Mac16,8 |
| Model number | Z1FF000HYD/A |
| Chip | Apple M4 Pro |
| CPU | 14 cores: 10 performance, 4 efficiency |
| GPU | Apple M4 Pro, 20 cores, Metal 4 |
| Memory | 48 GB |
| Built-in display | 3024 x 1964 Retina |
| macOS | macOS 26.5.1, build 25F80 |
| Kernel | Darwin 25.5.0 |
| Xcode | Xcode 26.2, build 17C52 |
| Swift | Apple Swift 6.2.3 |
| ADB | Android Debug Bridge 1.0.41, version 37.0.0-14910828, installed at `/opt/homebrew/bin/adb` |
| Optional local JDK | OpenJDK 17.0.19 at `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home` |
| Android SDK env | `ANDROID_HOME` and `ANDROID_SDK_ROOT` were unset in the shell capture |

Physical USB validation on this system:

| Receiver | Validated mode |
| --- | --- |
| Galaxy Tab S7 | Independent USB display at 1920 x 1200 @ 60 Hz. |
| Galaxy Z Fold 4 | Independent USB display, last captured at 1024 x 768 @ 60 Hz. |
| Two-device run | Galaxy Tab S7 and Galaxy Z Fold 4 connected simultaneously, with separate macOS displays instead of mirrored output. |
