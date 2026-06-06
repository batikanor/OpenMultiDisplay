## Summary

Describe the change and why it is needed.

## Scope

- [ ] macOS host
- [ ] Android receiver
- [ ] USB / ADB
- [ ] Wireless
- [ ] Documentation
- [ ] Packaging / release

## Testing

- [ ] `cd MacHost && swift test && swift build`
- [ ] `cd AndroidClient && ./gradlew testDebugUnitTest lintDebug assembleDebug`
- [ ] ktlint over Android main/test sources
- [ ] GitHub Actions macOS matrix passes (`macos-14`, `macos-15`, `macos-15-intel`, `macos-26`, `macos-26-intel`)
- [ ] GitHub Actions Android workflow passes
- [ ] Tested with one Android device
- [ ] Tested with two or more Android devices
- [ ] Tested unplugging one USB device while another stays connected
- [ ] Not applicable; explain below

## Notes

List remaining risks, follow-up work, or hardware used for testing.
