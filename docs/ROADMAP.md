# Roadmap

## Phase 1: Multi-Client Transport

- [x] Preserve upstream SideScreen history and MIT attribution.
- [x] Create fork identity and separate app IDs.
- [x] Run ADB reverse setup per authorized USB device.
- [x] Keep multiple receiver connections alive in `StreamingServer`.
- [x] Test with two physical Android devices attached over USB.

## Phase 2: Independent Displays

- [x] Introduce a `DisplayPipeline` model.
- [x] Create one virtual display per connected Android device.
- [x] Assign a unique Mac-side port per device.
- [x] Keep Android-side USB port stable at `54321`.
- [x] Route frames, stats, and keyframe requests per pipeline.
- [x] Route touch input to the owning virtual display.
- [x] Add per-device display profiles keyed by ADB serial.
- [x] Add a SwiftUI editor for per-device display profiles.

## Phase 3: Product Quality

- [x] Add regression tests for USB pipeline disconnect reconciliation.
- [ ] Add integration tests for end-to-end multi-client connection behavior.
- [x] Add packaging that does not overwrite upstream SideScreen.
- [x] Add CI checks for macOS 14/15/26, Apple silicon, Intel, Android unit tests, Android lint, and ktlint.
- [ ] Add signed and notarized release checks for macOS artifacts.
- [ ] Add performance presets for common devices.
- [x] Validate with Galaxy Tab S7 and Galaxy Z Fold 4.
- [ ] Validate physical hardware on MacBook Air, Intel MacBook Pro, MacBook Neo, and more Android receivers.
