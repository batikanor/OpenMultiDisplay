# Architecture

SideScreen Multi currently uses the upstream SideScreen protocol and keeps the Swift module name `SideScreen` while the public app identity is `SideScreen Multi`.

## Wireless / Single-Display Pipeline

```text
macOS virtual display
  -> ScreenCaptureKit / fallback capture
  -> VideoToolbox H.265 encoder
  -> StreamingServer
  -> one or more Android receiver connections
```

Wireless mode still uses this single-display path.

## USB Multi-Display Pipeline

```text
Android receiver 1
  -> virtual display 1
  -> ScreenCaptureKit / fallback capture 1
  -> VideoToolbox H.265 encoder 1
  -> StreamingServer on Mac port 54321
  -> adb -s serial1 reverse tcp:54321 tcp:54321

Android receiver 2
  -> virtual display 2
  -> ScreenCaptureKit / fallback capture 2
  -> VideoToolbox H.265 encoder 2
  -> StreamingServer on Mac port 54322
  -> adb -s serial2 reverse tcp:54321 tcp:54322
```

Each `DisplayPipeline` owns:

- a virtual display
- a capture source
- an encoder
- a streaming server
- client stats callbacks
- touch input mapping to the owning virtual display

## Design Constraints

- Android clients connect to `localhost:54321` in USB mode.
- ADB reverse mappings are per physical device, so multiple devices can use the same Android-side port.
- macOS needs separate virtual displays for true extended-desktop behavior.
- Touch input must map back to the owning virtual display, not a global display.
- Per-device display profiles are keyed by ADB serial and loaded from `~/.sidescreen-multi/devices.json`.

## Open Questions

- Whether the Android USB UI should expose a device profile or stay zero-config.
- How to handle two active touch sources at the same time.
