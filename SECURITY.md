# Security Policy

SideScreen Multi is early alpha software. Do not treat it as hardened or production audited.

## Supported Versions

Only the current `main` branch is supported during alpha development.

## Reporting Issues

Report security issues privately to:

```text
batikanor@gmail.com
```

Please include:

- affected commit or release
- host macOS version
- Android device/version
- reproduction steps
- logs if available

## Security Model

USB mode uses ADB reverse forwarding to expose the Mac streaming server to the Android device through the USB debugging channel. Wireless mode uses local-network connectivity and the upstream pairing/token model.

Keep USB debugging disabled when you are not actively developing or using the app.
