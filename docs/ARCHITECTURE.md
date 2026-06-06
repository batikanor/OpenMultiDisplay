# Architecture

SideScreen Multi currently uses the upstream SideScreen protocol and keeps the Swift module name `SideScreen` while the public app identity is `SideScreen Multi`.

## Current Alpha Pipeline

```text
macOS virtual display
  -> ScreenCaptureKit / fallback capture
  -> VideoToolbox H.265 encoder
  -> StreamingServer
  -> one or more Android receiver connections
```

This proves multi-client transport and USB setup. Every receiver sees the same virtual display.

## Target Pipeline

```text
Android receiver 1
  -> adb -s serial1 reverse tcp:54321 tcp:port1
  -> StreamingPipeline 1
  -> virtual display 1

Android receiver 2
  -> adb -s serial2 reverse tcp:54321 tcp:port2
  -> StreamingPipeline 2
  -> virtual display 2
```

Each `StreamingPipeline` should own:

- a virtual display
- a capture source
- an encoder
- a streaming server
- client stats
- touch input mapping

## Design Constraints

- Android clients connect to `localhost:54321` in USB mode.
- ADB reverse mappings are per physical device, so multiple devices can use the same Android-side port.
- macOS needs separate virtual displays for true extended-desktop behavior.
- Touch input must map back to the owning virtual display, not a global display.

## Open Questions

- Whether the Android USB UI should expose a device profile or stay zero-config.
- Whether each device should get a stable saved resolution by ADB serial.
- How to handle two active touch sources at the same time.
