# WattLeft

WattLeft is a macOS menu bar app that shows battery percentage, time remaining, battery health, cycle count, power mode, and time since unplugged.

Copyright (c) 2026 WattLeft contributors.

## Features

- Menu bar display: percentage or time remaining
- Battery details: charge, time remaining, status, cycles, condition, maximum capacity
- Power mode readout with a shortcut to System Settings
- Optional launch at login

## Requirements

- macOS 15.0 or later
- Xcode (current stable)

## Build

If you want to regenerate the Xcode project from `project.yml`:

```bash
brew install xcodegen
xcodegen
```

Build and run with Xcode by opening `WattLeft.xcodeproj`.

## Test

```bash
xcodebuild test -project WattLeft.xcodeproj -scheme WattLeft -destination "platform=macOS"
```

## Project Layout

- `WattLeft/App` - App code (SwiftUI views, model, battery reader)
- `WattLeft/Tests` - Unit tests
- `project.yml` - XcodeGen project definition

## Notes

The "On battery for" timer starts counting when WattLeft observes the AC → battery transition.

## License

GPL-3.0. See `LICENSE`.
