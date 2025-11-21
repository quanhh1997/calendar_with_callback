# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-01-XX

### Added
- Initial release
- Support for adding events to native calendar on iOS and Android
- Native calendar UI integration (EKEventEditViewController on iOS, Intent on Android)
- Event ID and Calendar ID callback after user confirms
- Event deletion functionality using event ID
- Permission checking and requesting
- Support for all-day events
- Support for reminders (iOS only)
- Support for location and description
- Flexible date format parsing
- Comprehensive error handling

### Features
- Opens native calendar editor for better UX
- Returns event ID and calendar ID via callback
- Cross-platform support (iOS 13.0+, Android API 21+)
- Automatic permission handling
