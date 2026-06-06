# Roadmap

## Phase 1: Multi-Client Transport

- [x] Preserve upstream SideScreen history and MIT attribution.
- [x] Create fork identity and separate app IDs.
- [x] Run ADB reverse setup per authorized USB device.
- [x] Keep multiple receiver connections alive in `StreamingServer`.
- [ ] Test with two physical Android devices attached over USB.

## Phase 2: Independent Displays

- [x] Introduce a `DisplayPipeline` model.
- [x] Create one virtual display per connected Android device.
- [x] Assign a unique Mac-side port per device.
- [x] Keep Android-side USB port stable at `54321`.
- [x] Route frames, stats, and keyframe requests per pipeline.
- [x] Route touch input to the owning virtual display.
- [x] Add per-device display profiles keyed by ADB serial.
- [ ] Add a SwiftUI editor for per-device display profiles.

## Phase 3: Product Quality

- [ ] Add integration tests for multi-client connection behavior.
- [ ] Add packaging that does not overwrite upstream SideScreen.
- [ ] Add release checks for macOS and Android artifacts.
- [ ] Add performance presets for common devices.
- [ ] Validate with Galaxy Tab S7 and Galaxy Z Fold 4.
