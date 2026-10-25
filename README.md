# Passata

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/joao-lustosa/Passata/actions/workflows/ci.yml/badge.svg)](https://github.com/joao-lustosa/Passata/actions/workflows/ci.yml)
![Swift 6.0](https://img.shields.io/badge/swift-6.0-F05138.svg)
![Platforms](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey.svg)
[![Sponsor](https://img.shields.io/badge/sponsor-%E2%9D%A4-ea4aaa.svg)](https://github.com/sponsors/joao-lustosa)

A native Pomodoro timer for iOS and macOS, built entirely with SwiftUI — no external dependencies.

## Status

Actively developed. The core timer, settings, and completion feedback are implemented and tested on both platforms, along with:

- iOS Live Activities for the Lock Screen and Dynamic Island (compact and expanded)
- A home screen widget extension
- An adaptive app icon
- Native macOS support, including background operation through a menu bar item so the timer keeps running after the main window is closed
- Editable focus and break durations and sessions per cycle, with direct entry and a reset to defaults
- A completion chime that respects iPhone Silent Mode; notification sounds always follow the system setting
- Restart Cycle from the Reset control
- Catch-up for phases missed while the app is backgrounded, with chained completion notifications and best-effort background refresh

## Requirements

- Xcode 27
- Swift 6.0 (Swift 6 language mode)
- iOS 26.5+ / macOS 26.5+

## Continuous Integration

Pushes to `develop` and `main`, and pull requests targeting either branch, run the unit test suite on macOS and iOS via GitHub Actions — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## TestFlight builds

From a non-interactive shell, source the local App Store Connect environment file and run the dry run first:

```sh
source ~/.appstoreconnect/passata.env
Scripts/upload-testflight.sh --dry-run
```

The dry run archives and exports locally, validates the app's export-compliance key and the embedded widget display name, and never uploads. The build number defaults to the next value after the project's `CURRENT_PROJECT_VERSION`; pass `--build-number N` to choose one explicitly. `--marketing-version VERSION` overrides the project marketing version for that build only.

Only after explicit user approval, run `Scripts/upload-testflight.sh --upload` to send the exported archive to App Store Connect. The script reads the API key from `~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8`; it does not display or store credentials. If non-interactive signing cannot access the Apple Distribution identity, unlock/authorize that identity once in Keychain Access for command-line use, then rerun the dry run. Do not change keychain access settings automatically.

## Support

Passata is free and will stay free. If you'd like to support development, you can sponsor it on [GitHub Sponsors](https://github.com/sponsors/joao-lustosa).

## License

MIT — see [LICENSE](LICENSE).
