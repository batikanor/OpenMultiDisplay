# Contributing

TetherSpan is an early fork of SideScreen. Contributions should keep the project focused on reliable Android receivers for macOS, especially USB-first multi-device workflows.

## Development Setup

Prerequisites:

- macOS 14 or newer
- Xcode command line tools
- Swift 5.9+
- Android Studio or an Android SDK/JDK setup
- Android platform-tools (`adb`)

Build the Mac host:

```bash
cd MacHost
swift build
```

Build the Android receiver:

```bash
cd AndroidClient
./gradlew assembleDebug
```

## Contribution Rules

- Keep changes scoped and reviewable.
- Preserve MIT license attribution for upstream SideScreen code.
- Test on real Android hardware when changing USB, decoder, touch, or display behavior.
- Document user-visible behavior changes in `README.md` or `docs/`.
- Do not claim independent multi-display support until a per-device virtual-display pipeline is implemented and tested.

## Pull Request Checklist

- [ ] macOS host builds with `swift build`
- [ ] Android receiver builds, or the change does not affect Android
- [ ] USB behavior was tested or the risk is documented
- [ ] Multi-device behavior was tested when relevant
- [ ] Documentation was updated for user-facing changes

## Commit Style

Use concise conventional prefixes when practical:

- `feat:`
- `fix:`
- `docs:`
- `test:`
- `chore:`

Example:

```text
feat: keep multiple USB receiver connections alive
```
