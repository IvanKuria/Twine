# Contributing to Twine

Thank you for your interest in contributing. Twine is a native macOS keepsake app built with Swift 6, SwiftUI + AppKit, and SwiftData. Contributions of all kinds are welcome: bug fixes, new features, map themes, importers, and localization.

---

## Build and run

**Requirements:** Xcode 26, macOS 14+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/IvanKuria/Twine.git
cd twine
xcodegen generate
open Twine.xcodeproj      # then press Cmd-R
```

The generated `.xcodeproj` is git-ignored. Always run `xcodegen generate` after pulling changes to `project.yml`.

---

## Tests

The pure logic lives in `TwineKit`. Run its test suite with:

```bash
cd Packages/TwineKit
swift test
```

**This suite must stay green.** All 18 tests must pass before you open a PR. If your change touches clustering, geocoding, stats, projection, or the import pipeline, add or update tests in `Packages/TwineKit/Tests/`.

UI changes are verified by running the app in Xcode and exercising the changed surface.

---

## Code style

**Keep `TwineKit` pure.** The `Packages/TwineKit` package must have no imports from `SwiftUI`, `AppKit`, `PhotoKit`, `UIKit`, or any Apple framework that depends on a running app. It is a plain Swift package. All deterministic logic -- clustering, geocoding, stats, projection, importers -- lives here.

**App code goes in the `Twine` target.** PhotoKit authorization, thumbnail loading, the Canvas map renderer, SwiftData stores, and all UI belong in `Twine/`.

Follow the existing Swift 6 concurrency patterns: `@MainActor` on view models, structured concurrency for background work, no `DispatchQueue.main.async` bypasses.

---

## Adding a contribution-registry item

The registry is how Twine grows without bloating the core. A registry PR is typically small, self-contained, and mergeable in one review round.

### Map theme or poster style

A theme is a struct (or enum case) in `TwineKit` that vends a set of named colors and optional texture references:

1. Add your theme definition to `Sources/TwineKit/Themes/`. It should expose land fill, ocean fill, border stroke, pin tint, thread color, and paper texture name (optional).
2. Register it in the theme catalog (the existing array/enum in that directory).
3. The app's `Canvas` renderer reads from the catalog at draw time -- no app-side changes needed for a pure theme.
4. Add a preview screenshot to your PR description so reviewers can see the result.

### Pin or thread style

A pin style is a small drawing closure (or a `PinDescriptor` value type) that the `Canvas` renderer calls per pin. A thread style controls stroke weight, dash pattern, and opacity.

1. Add the descriptor to `Sources/TwineKit/Styles/`.
2. Register it in the styles catalog.
3. Verify that the style renders correctly at world zoom and at city-cluster zoom.

### Importer

An importer converts a third-party data format into `[PhotoSample]`, the same type that the Photos scan produces. This means importers drop straight into the existing clustering and geocoding pipeline.

1. Create a new file in `Sources/TwineKit/Importers/`, e.g. `GPXImporter.swift`.
2. Implement the `SampleImporter` protocol:
   ```swift
   public protocol SampleImporter {
       func importSamples(from url: URL) throws -> [PhotoSample]
   }
   ```
3. Add unit tests in `Tests/TwineKitTests/Importers/` using a small, checked-in sample file (keep it under 50 KB).
4. Register the importer in the importers catalog so the app's "Import from file" sheet can offer it.

Common importers to build: GPX tracks, Google Takeout `Records.json`, Swarm/Foursquare checkin CSV.

---

## Pull request checklist

- [ ] `cd Packages/TwineKit && swift test` passes (all 18 tests green, plus any new ones you added).
- [ ] No new imports from UI or app frameworks in `TwineKit`.
- [ ] No network entitlement added.
- [ ] If you added a theme or style: include a screenshot in the PR description.
- [ ] If you added an importer: include a small sample file and tests.
- [ ] Commit messages are clear and describe the "why."

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
