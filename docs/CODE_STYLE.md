# Code Style

OpenMultiDisplay uses a small, explicit style guide so the macOS host, Android
receiver, website, and docs feel like one project. The goal is predictable,
reviewable code that is easy to test and hard to regress.

## Reference Projects

These projects are references for taste and engineering discipline, not sources
to copy from:

| Area | Reference | What to copy |
| --- | --- | --- |
| macOS Swift | IINA, CodeEdit | Native macOS structure, clear Swift names, focused UI components, disciplined contributor docs. |
| Android Kotlin | Now in Android | Kotlin style, testable state boundaries, Android-first architecture. |
| Streaming tooling | scrcpy, Moonlight | Protocol clarity, direct troubleshooting docs, latency-aware implementation notes. |
| Display product polish | BetterDisplay | Compatibility communication, release notes, user-facing limitations. |

Baseline language rules:

- Swift follows the Swift API Design Guidelines and is checked with SwiftLint.
- Kotlin follows the Android Kotlin style guide and is checked with ktlint.
- Shell scripts prefer POSIX-safe, readable control flow unless a script already
  requires Bash.
- Website code stays static and dependency-light unless a feature needs a build
  system.

## Repository Rules

- Keep changes scoped. A PR should usually touch one product area: macOS host,
  Android receiver, website, docs, or release tooling.
- Names must describe the domain object, not the implementation accident.
  Prefer `USBPipelineReconciler` over `Helper`, `DeviceDisplaySpec` over
  `Config2`, and `metadataFrameHeaderSize` over a raw `14`.
- Comments explain why a choice exists, what invariant is protected, or what
  external behavior is surprising. Do not comment obvious assignments.
- User-visible text, diagnostics, and comments should be English and ASCII unless
  quoting an external product name or preserving legal attribution.
- Avoid broad rewrites while hardware behavior is still alpha. Refactor near
  tests first, then expand only after the validation path is clear.
- Prefer pure functions and small value types for protocol, parsing, pairing,
  reconciliation, and configuration behavior. These should have unit tests.
- Protocol numbers, packet sizes, timeouts, ports, and retry counts must be named
  constants.
- Keep hardware-dependent code behind small boundaries so unit tests can cover
  the policy separately from ADB, ScreenCaptureKit, MediaCodec, or sockets.

## Swift Rules

- Use `PascalCase` for types and `camelCase` for functions, properties, enum
  cases, and local values.
- Keep UI state on the main actor. Mark functions `@MainActor` when they mutate
  SwiftUI/ObservableObject state or AppKit objects.
- Prefer `guard` for required preconditions and early exits.
- Use `Task.detached` only when the work is intentionally off the main actor.
  Return to `MainActor` before touching app state.
- Do not hide errors in core startup/shutdown paths. If an error is intentionally
  non-fatal, leave a short comment explaining why continuing is acceptable.
- Use `debugLog` for host diagnostics that are useful in `/tmp/openmultidisplay.log`.
  Use `print` only for very short local development output.
- Keep SwiftUI views composable. Extract repeated controls or sections when it
  removes real duplication or makes state ownership clearer.

## Kotlin Rules

- Use one top-level Android component per file. Small protocol/state helpers may
  live in the same file only when they are tightly coupled.
- Prefer immutable `val` values. Use `var` only for lifecycle state, metrics,
  and buffers that genuinely change over time.
- Keep socket, decoder, and ADB work off the main thread. Use lifecycle-aware
  coroutines from activities and explicit IO dispatchers for blocking work.
- Use sealed classes or enums for connection modes, protocol states, and typed
  error outcomes.
- Keep callback contracts precise. Document callback parameters when their
  meaning is not obvious, such as frame size versus buffer size.
- Release pooled buffers on all non-decoding paths. Tests should cover parser and
  policy code; physical validation covers device-specific decoder behavior.
- Diagnostics should use `DiagLog` or Android `Log` consistently and avoid
  decorative prefixes.

## Tests and Validation

Before pushing code that can affect behavior, run:

```bash
./scripts/validate_all.sh
```

For smaller edits, run the narrowest relevant check first, then the full suite
before pushing:

```bash
cd MacHost
swift test
swift build
```

```bash
cd AndroidClient
./gradlew testDebugUnitTest lintDebug assembleDebug
```

```bash
node scripts/validate_website.mjs
git diff --check
```

Add or update tests when changing:

- Wire protocol encoding, decoding, packet sizes, or flags.
- Auth, pairing URLs, token handling, or connection modes.
- USB device reconciliation, per-device display configuration, or disconnect
  behavior.
- Input prediction, latency measurement, keyframe policy, or decoder recovery.
- Website links, anchors, asset references, or Vercel/static-site configuration.

## Documentation Style

- Keep the root README concise. Put detailed compatibility, testing, USB setup,
  architecture, and release notes in focused docs.
- Tables are preferred for support matrices and command summaries.
- Call out what is proven, what is expected, and what is not proven yet.
- Do not overstate hardware compatibility. If it has not been physically tested,
  say so directly.
