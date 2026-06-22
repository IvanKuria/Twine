# Twine

A keepsake travel-memory map for macOS. Pin your adventures on a beautiful map using the location and date metadata from your photos.

## Requirements

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Getting Started

```bash
brew install xcodegen
xcodegen generate
open Twine.xcodeproj
```

## Architecture

- `Packages/TwineKit` — Pure Swift domain layer (no UI, no AppKit, no networking)
- `Twine/` — SwiftUI macOS app

## License

MIT
