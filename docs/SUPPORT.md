# Support Matrix

OpenMultiDisplay is developed as a macOS 14+ host application plus an Android 8.0+
receiver. The macOS host is a universal Swift executable, so the intended Mac
host support is both Apple silicon and Intel Mac laptops that can run macOS 14
or newer.

Official Apple compatibility references:

- macOS Sonoma 14: <https://support.apple.com/en-mt/105113>
- macOS Sequoia 15: <https://support.apple.com/en-us/120282>
- macOS Tahoe 26: <https://support.apple.com/en-us/122867>

## Mac Laptop Support

OpenMultiDisplay's host target is macOS 14 or newer. A Mac laptop is treated as
supported when Apple officially supports that laptop on macOS 14 Sonoma,
macOS 15 Sequoia, or macOS 26 Tahoe and the machine has enough CPU/GPU headroom
for one capture and encoder pipeline per Android receiver.

| Laptop type | Versions treated as supported | Why |
| --- | --- | --- |
| MacBook Pro on macOS 14 Sonoma | MacBook Pro 2018 and later, including 2018 13-inch/15-inch, 2019 13-inch/15-inch/16-inch, 2020 13-inch Intel, 2020 13-inch M1, 2021 14-inch/16-inch, 2022 13-inch M2, and 2023 14-inch/16-inch models. | Apple lists these MacBook Pro models as Sonoma-compatible, and Sonoma satisfies OpenMultiDisplay's macOS 14+ host target. |
| MacBook Pro on macOS 15 Sequoia | MacBook Pro 2018 and later, including the 2024 14-inch/16-inch models listed by Apple. | Apple lists MacBook Pro 2018 and later for Sequoia. This is the broadest official current laptop path for Intel MacBook Pro support. |
| MacBook Pro on macOS 26 Tahoe | MacBook Pro 16-inch 2019; 13-inch 2020 with Four Thunderbolt 3 ports; 13-inch M1 2020; 14-inch/16-inch 2021; 13-inch M2 2022; 14-inch/16-inch 2023; 14-inch/16-inch 2024; and 14-inch M5. | Apple lists this narrower set for Tahoe. Earlier 2018 MacBook Pro models and several Intel 2019/2020 variants remain supported only on Sonoma/Sequoia for this project. |
| MacBook Air on macOS 14 Sonoma | MacBook Air Retina 13-inch 2018, 2019, and 2020; MacBook Air M1 2020; MacBook Air M2 2022; MacBook Air 15-inch M2 2023; and MacBook Air 13-inch/15-inch M3 2024. | Apple lists these MacBook Air models as Sonoma-compatible. These are supported when running macOS 14 or newer. |
| MacBook Air on macOS 15 Sequoia | MacBook Air Retina 13-inch 2020; MacBook Air M1 2020; MacBook Air M2 2022; MacBook Air 15-inch M2 2023; MacBook Air 13-inch/15-inch M3 2024; and MacBook Air 13-inch/15-inch M4 2025. | Apple lists MacBook Air 2020 and later for Sequoia. This drops the 2018 and 2019 Intel MacBook Air models from the Sequoia path. |
| MacBook Air on macOS 26 Tahoe | MacBook Air M1 2020, M2 2022, 15-inch M2 2023, 13-inch/15-inch M3 2024, and 13-inch/15-inch M4 2025. | Apple lists Apple-silicon MacBook Air models for Tahoe. Intel MacBook Air models are not in Apple's Tahoe laptop list. |
| MacBook Neo on macOS 26 Tahoe | MacBook Neo 13-inch with A18 Pro. | Apple lists this laptop for Tahoe. It should meet the OS requirement, but it is not physically tested in this repository. |
| 12-inch MacBook | Not supported. | Apple's Sonoma, Sequoia, and Tahoe compatibility lists do not include 12-inch MacBook models, and OpenMultiDisplay's host target is macOS 14+. |

## Practical Requirements

- macOS 14 or newer.
- Screen Recording permission for the macOS host app.
- Android platform-tools / `adb` for USB mode.
- Android receiver with USB debugging enabled and authorized.
- H.265 decode support on the Android receiver.
- Enough host GPU/CPU headroom for one capture and encoder pipeline per Android device.

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
| macOS | macOS 26.5.1, build 25F80 |
| Kernel | Darwin 25.5.0 |
| Xcode | Xcode 26.2, build 17C52 |
| Swift | Apple Swift 6.2.3 |
| ADB | Android Debug Bridge 1.0.41, version 37.0.0-14910828, installed at `/opt/homebrew/bin/adb` |

During local validation, the forked host streamed two independent USB displays
at the same time:

- Galaxy Tab S7, 1920 x 1200 @ 60 Hz.
- Galaxy Z Fold 4, 1024 x 768 @ 60 Hz in the last captured system state.

The Android Java runtime was not available from the shell during this capture,
so Android build verification requires installing or selecting a JDK before
running Gradle locally.
