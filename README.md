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

## Requirements

- Xcode 27
- Swift 6.0 (Swift 6 language mode)
- iOS 26.5+ / macOS 26.5+

## Continuous Integration

Every push runs the unit test suite on macOS and iOS via GitHub Actions — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Support

Passata is free and will stay free. If you'd like to support development, you can sponsor it on [GitHub Sponsors](https://github.com/sponsors/joao-lustosa).

## License

MIT — see [LICENSE](LICENSE).
