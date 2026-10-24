# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Editable focus and break durations, sessions per cycle, and reset-to-default settings.
- A completion chime with a setting to respect iPhone Silent Mode.
- Restart Cycle from the Reset control and catch-up for phases missed while the app is backgrounded.
- Adaptive layouts for accessibility text sizes and compact Live Activity presentations.

### Changed

- Preserve saved settings when newer settings fields are absent, and keep the timer ring and countdown aligned when durations change.
- Share widget countdown formatting, session-dot rules, and settings defaults across app targets.

### Fixed

- Keep the duration settings readable at large text sizes and show an explicit Cancel action in duration prompts.
- Keep Live Activity countdowns bounded in narrow presentations and render the minimal presentation as a ring only.
