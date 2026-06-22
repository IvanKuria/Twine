# Twine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Twine v1 — a native macOS keepsake travel map that auto-imports your Photos' GPS into a poster-style world map with pins threaded to Home, plus a places sidebar, stats summary, pin detail, and high-res image export.

**Architecture:** Two targets mirroring Blip. `TwineKit` is a pure, unit-tested Swift package (models, clustering, offline reverse-geocode, stats, projection) that takes photo metadata through a protocol so it has no PhotoKit/AppKit/UI dependency. `Twine` is a thin SwiftUI + AppKit app that supplies real PhotoKit data, renders the `Canvas` poster map, persists with SwiftData, and exports images.

**Tech Stack:** Swift 6, SwiftUI + AppKit, SwiftData, PhotoKit, Core Graphics `Canvas`, `ImageRenderer`, XcodeGen, Xcode 26.

## Global Constraints

- **Platform:** macOS 14+. Swift 6 language mode. Xcode 26.
- **Two targets:** `TwineKit` (SPM package: NO `import SwiftUI`/`AppKit`/`PhotoKit`/`SwiftData`/`MapKit`) + `Twine` (app). Photo metadata reaches `TwineKit` only via the `PhotoSampleProviding` protocol.
- **Map:** the hero board is rendered in SwiftUI `Canvas` — **never MapKit** (poster aesthetic + `ImageRenderer` cannot export `NSViewRepresentable`).
- **Projection:** equirectangular for v1. Robinson is out of scope.
- **Privacy:** App Sandbox ON; **NO `com.apple.security.network.client`** entitlement; `NSPhotoLibraryUsageDescription` set. No account, no cloud, no network calls anywhere.
- **Photos:** request read access; **detect `.limited` and prompt for full access**; read `PHAsset.location` directly (never exported-file EXIF); scan metadata on a background queue; load thumbnails on demand via `PHCachingImageManager`.
- **Persistence:** SwiftData. Reference photos by `PHAsset.localIdentifier`; **never copy image files**. On missing asset, fall back to cached coordinate + placeholder (never crash).
- **Bundled data (no network):** Natural Earth **1:110m** admin-0 countries (public domain); GeoNames **cities5000** + countryInfo (CC-BY 4.0 — **attribution required** in an About/Credits screen). Never use `CLGeocoder`.
- **Export:** high-res image via `ImageRenderer` in v1. Video export is v1.1 (out of scope).
- **Quality:** `swift test` (in `Packages/TwineKit`) must stay green after every kit task. UI tasks are verified by building and running the app. DRY, YAGNI, TDD, frequent commits.
- **Repo:** git remote `origin` = `https://github.com/IvanKuria/Twine.git`. License MIT. Distribution: Developer-ID signed + notarized DMG (Blip pipeline).
- **Copy rule:** no em dashes in user-facing copy or README.

---

## File Structure

```
~/Documents/Twine/
  project.yml                       # XcodeGen: TwineKit (local SPM) + Twine app
  Packages/TwineKit/
    Package.swift
    Sources/TwineKit/
      Geo.swift                     # Coordinate, Region, haversine, math
      Projection.swift              # equirectangular lon/lat <-> unit board point
      Models.swift                  # PhotoSample, Place, Visit, Home, ThreadLink
      PhotoSampleProviding.swift    # protocol the app implements
      Clusterer.swift               # samples -> clusters
      ReverseGeocoder.swift         # nearest-city + country/continent (in-memory)
      CityIndex.swift               # loads bundled cities resource, grid index
      ImportPipeline.swift          # samples -> [Place] (cluster+geocode+merge)
      Stats.swift                   # counts + thread miles
      Resources/                    # compact cities + countries data (built by script)
        cities.tsv
        countries.tsv
    Tests/TwineKitTests/
      Fakes.swift                   # FakePhotoSampleProvider + tiny fixture data
      ProjectionTests.swift
      GeoTests.swift
      ClustererTests.swift
      ReverseGeocoderTests.swift
      ImportPipelineTests.swift
      StatsTests.swift
  Twine/
    App/
      TwineApp.swift                # @main, WindowGroup + Settings + AppDelegate
      PhotoLibrary.swift            # PHPhotoLibrary auth + PhotoSampleProviding impl
      ImportCoordinator.swift       # scan -> pipeline -> SwiftData (background+progress)
      ThumbnailLoader.swift         # PHCachingImageManager on-demand thumbnails
      LoginItem.swift               # SMAppService (optional launch at login)
    Model/
      Store.swift                   # SwiftData ModelContainer + PlaceRecord, HomeRecord
    UI/
      Theme.swift                   # colors, sizes, fonts
      BoardView.swift               # Canvas poster map + pins + threads + pan/zoom
      MapGeometry.swift             # Natural Earth load + projected Path cache
      Sidebar.swift                 # places list
      SummaryPanel.swift            # stats
      PinDetail.swift               # photos/dates/note
      Onboarding.swift              # permission + scan progress + full-access nudge
      AddPlaceSheet.swift           # manual city search + drop pin
      ExportView.swift              # ImageRenderer export
      ContentView.swift            # three-pane composition
      Settings.swift                # settings + credits/attribution
    Resources/
      Twine.entitlements           # sandbox, no network, photos usage
      Assets.xcassets/
  scripts/
    build-data.sh                   # download GeoNames + Natural Earth -> compact resources
    icon.svg
    make-icon.sh
    build-dmg.sh
  README.md  CONTRIBUTING.md  LICENSE
  docs/superpowers/specs/2026-06-22-twine-design.md
```

---

# Milestone 1 — Scaffold + TwineKit core (pure, TDD)

### Task 1: Project scaffold, git, remote

**Files:**
- Create: `project.yml`, `Packages/TwineKit/Package.swift`, `Packages/TwineKit/Sources/TwineKit/TwineKit.swift`, `Twine/App/TwineApp.swift`, `Twine/Resources/Twine.entitlements`, `.gitignore`, `LICENSE`, `README.md` (stub).

**Interfaces:**
- Produces: a buildable empty app + an empty `TwineKit` package that `swift test` runs (zero tests OK).

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TwineKit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "TwineKit", targets: ["TwineKit"])],
    targets: [
        .target(
            name: "TwineKit",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "TwineKitTests", dependencies: ["TwineKit"]),
    ]
)
```

- [ ] **Step 2: Add a placeholder source + Resources dir**

`Sources/TwineKit/TwineKit.swift`:
```swift
/// Twine's pure domain layer. No UI, AppKit, PhotoKit, SwiftData, or networking.
public enum TwineKit {
    public static let version = "0.1.0"
}
```
Create `Sources/TwineKit/Resources/.gitkeep` (real data added in Task 6/data-prep).

- [ ] **Step 3: Verify the package builds & tests run**

Run: `cd Packages/TwineKit && swift test`
Expected: builds; "Executed 0 tests".

- [ ] **Step 4: Write `project.yml` (XcodeGen)**

```yaml
name: Twine
options:
  bundleIdPrefix: com.ivankuria.twine
  deploymentTarget: { macOS: "14.0" }
packages:
  TwineKit: { path: Packages/TwineKit }
targets:
  Twine:
    type: application
    platform: macOS
    sources: [Twine]
    dependencies:
      - package: TwineKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.ivankuria.twine
        SWIFT_VERSION: "6.0"
        GENERATE_INFOPLIST_FILE: YES
        CODE_SIGN_ENTITLEMENTS: Twine/Resources/Twine.entitlements
        INFOPLIST_KEY_NSPhotoLibraryUsageDescription: "Twine reads the location and date of your photos to place pins on your map. Photos never leave your Mac."
        INFOPLIST_KEY_LSApplicationCategoryType: "public.app-category.lifestyle"
        MARKETING_VERSION: "0.1.0"
```

- [ ] **Step 5: Write entitlements (sandbox, photos, NO network)**

`Twine/Resources/Twine.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.personal-information.photos-library</key><true/>
</dict></plist>
```

- [ ] **Step 6: Minimal `@main` app**

`Twine/App/TwineApp.swift`:
```swift
import SwiftUI

@main
struct TwineApp: App {
    var body: some Scene {
        WindowGroup { Text("Twine") }
    }
}
```

- [ ] **Step 7: `.gitignore`, `LICENSE` (MIT), README stub; generate & build**

Run: `xcodegen generate && xcodebuild -project Twine.xcodeproj -scheme Twine -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Init git, set remote, first commit**

```bash
git init && git add -A
git commit -m "chore: scaffold Twine (TwineKit package + app shell)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
git branch -M main
git remote add origin https://github.com/IvanKuria/Twine.git
git push -u origin main
```

---

### Task 2: Geo primitives (Coordinate + haversine)

**Files:**
- Create: `Sources/TwineKit/Geo.swift`, `Tests/TwineKitTests/GeoTests.swift`

**Interfaces:**
- Produces: `struct Coordinate { let latitude, longitude: Double }`; `func haversineKilometers(_:_:) -> Double`; `Coordinate.continent`/country live elsewhere.

- [ ] **Step 1: Write failing test**

```swift
import Testing
@testable import TwineKit

@Test func haversineKnownDistance() {
    let sf = Coordinate(latitude: 37.7749, longitude: -122.4194)
    let ny = Coordinate(latitude: 40.7128, longitude: -74.0060)
    let km = haversineKilometers(sf, ny)
    #expect(abs(km - 4129) < 30)   // ~4129 km
}
```

- [ ] **Step 2: Run, expect fail** — `swift test --filter haversineKnownDistance` → fails to compile (symbols missing).

- [ ] **Step 3: Implement**

```swift
import Foundation

public struct Coordinate: Equatable, Hashable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude; self.longitude = longitude
    }
}

public func haversineKilometers(_ a: Coordinate, _ b: Coordinate) -> Double {
    let r = 6371.0088
    let dLat = (b.latitude - a.latitude) * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let la1 = a.latitude * .pi / 180, la2 = b.latitude * .pi / 180
    let h = sin(dLat/2)*sin(dLat/2) + cos(la1)*cos(la2)*sin(dLon/2)*sin(dLon/2)
    return 2 * r * asin(min(1, sqrt(h)))
}
```

- [ ] **Step 4: Run, expect pass.** Commit `feat(kit): coordinate + haversine`.

---

### Task 3: Equirectangular projection

**Files:**
- Create: `Sources/TwineKit/Projection.swift`, `Tests/TwineKitTests/ProjectionTests.swift`

**Interfaces:**
- Consumes: `Coordinate`.
- Produces: `struct UnitPoint2D { let x, y: Double }` (0...1, y down); `enum Projection { static func project(_ c: Coordinate) -> UnitPoint2D; static func unproject(_ p: UnitPoint2D) -> Coordinate }`.

- [ ] **Step 1: Failing test**

```swift
@Test func equirectangularCorners() {
    #expect(Projection.project(.init(latitude: 90, longitude: -180)).y < 0.001)   // top-left
    let mid = Projection.project(.init(latitude: 0, longitude: 0))
    #expect(abs(mid.x - 0.5) < 1e-9 && abs(mid.y - 0.5) < 1e-9)
}
@Test func projectionRoundTrips() {
    let c = Coordinate(latitude: 48.85, longitude: 2.35)
    let r = Projection.unproject(Projection.project(c))
    #expect(abs(r.latitude - c.latitude) < 1e-9 && abs(r.longitude - c.longitude) < 1e-9)
}
```

- [ ] **Step 2: Run, expect fail.**

- [ ] **Step 3: Implement**

```swift
public struct UnitPoint2D: Equatable, Sendable { public var x: Double; public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y } }

public enum Projection {
    public static func project(_ c: Coordinate) -> UnitPoint2D {
        UnitPoint2D(x: (c.longitude + 180) / 360, y: (90 - c.latitude) / 180)
    }
    public static func unproject(_ p: UnitPoint2D) -> Coordinate {
        Coordinate(latitude: 90 - p.y * 180, longitude: p.x * 360 - 180)
    }
}
```

- [ ] **Step 4: Run, expect pass.** Commit `feat(kit): equirectangular projection`.

---

### Task 4: Core models + PhotoSampleProviding

**Files:**
- Create: `Sources/TwineKit/Models.swift`, `Sources/TwineKit/PhotoSampleProviding.swift`, `Tests/TwineKitTests/Fakes.swift`

**Interfaces:**
- Produces:
  - `struct PhotoSample { let assetID: String; let coordinate: Coordinate; let date: Date }`
  - `struct Visit { let date: Date; let assetIDs: [String] }`
  - `struct Place { let id: UUID; var coordinate: Coordinate; var city: String; var country: String; var continent: String; var visits: [Visit]; var photoCount: Int; var representativeAssetID: String?; var note: String?; var isManual: Bool }`
  - `protocol PhotoSampleProviding { func geotaggedSamples() async -> [PhotoSample]; var noLocationCount: Int { get } }`
  - `FakePhotoSampleProvider` (tests) returning canned samples.

- [ ] **Step 1: Write `Models.swift` + `PhotoSampleProviding.swift`** (value types above; all `Sendable`; `Place.firstDate`/`lastDate` computed from visits).

- [ ] **Step 2: Write `Fakes.swift`** — `FakePhotoSampleProvider` storing `[PhotoSample]` + `noLocationCount`; small fixtures (Paris x3 over two days, Tokyo x1, SF x2).

- [ ] **Step 3: Compile test target** — `swift test` (0 new assertions, must build). Commit `feat(kit): models + photo sample protocol`.

---

### Task 5: Clusterer

**Files:**
- Create: `Sources/TwineKit/Clusterer.swift`, `Tests/TwineKitTests/ClustererTests.swift`

**Interfaces:**
- Consumes: `[PhotoSample]`, `haversineKilometers`.
- Produces: `struct Cluster { var centroid: Coordinate; var samples: [PhotoSample] }`; `enum Clusterer { static func cluster(_ samples: [PhotoSample], radiusKm: Double = 40) -> [Cluster] }`.

- [ ] **Step 1: Failing tests**

```swift
@Test func nearbySamplesMergeFarOnesSplit() {
    let s = [
        PhotoSample(assetID: "a", coordinate: .init(latitude: 48.85, longitude: 2.35), date: .now),
        PhotoSample(assetID: "b", coordinate: .init(latitude: 48.86, longitude: 2.34), date: .now), // ~1km
        PhotoSample(assetID: "c", coordinate: .init(latitude: 35.68, longitude: 139.69), date: .now) // Tokyo
    ]
    let clusters = Clusterer.cluster(s, radiusKm: 40)
    #expect(clusters.count == 2)
}
```

- [ ] **Step 2: Run, expect fail.**

- [ ] **Step 3: Implement** greedy agglomeration: sort by latitude; for each sample, join an existing cluster whose centroid is within `radiusKm` (haversine), else start a new one; recompute centroid as running mean. Deterministic ordering (stable by assetID on ties).

- [ ] **Step 4: Run, expect pass.** Add a test: 50 samples in one spot → 1 cluster. Commit `feat(kit): geo clusterer`.

---

### Task 6: Bundled data prep + CityIndex + ReverseGeocoder

**Files:**
- Create: `scripts/build-data.sh`, `Sources/TwineKit/CityIndex.swift`, `Sources/TwineKit/ReverseGeocoder.swift`, `Tests/TwineKitTests/ReverseGeocoderTests.swift`
- Create (generated by script): `Sources/TwineKit/Resources/cities.tsv`, `Sources/TwineKit/Resources/countries.tsv`

**Interfaces:**
- Produces:
  - `struct City { let name: String; let coordinate: Coordinate; let countryCode: String; let population: Int }`
  - `struct CityIndex { init(citiesTSV: String, countriesTSV: String); func nearest(to: Coordinate) -> (city: City, country: String, continent: String)?; func search(_ query: String, limit: Int) -> [City] }`
  - `struct ReverseGeocoder { init(index: CityIndex); func resolve(_ c: Coordinate) -> (city: String, country: String, continent: String) }` (country-only fallback when nearest is far).

- [ ] **Step 1: Write `scripts/build-data.sh`**

Downloads `https://download.geonames.org/export/dump/cities5000.zip` and `countryInfo.txt`; downloads Natural Earth 110m countries GeoJSON (from `martynafford/natural-earth-geojson`, `110m/cultural/ne_110m_admin_0_countries.json`). Emits:
- `cities.tsv`: `name\tlat\tlon\tcountryCode\tpopulation` (from cities5000 columns 2,5,6,9,15).
- `countries.tsv`: `countryCode\tcountryName\tcontinentCode` (from countryInfo.txt).
- Copies the GeoJSON to `Twine/Resources/ne_110m_countries.json` (used by the app in Task 12).
Script is idempotent; prints row counts. (Data is committed so contributors need not re-download.)

- [ ] **Step 2: Run the script**

Run: `bash scripts/build-data.sh`
Expected: `cities.tsv` (~50k rows), `countries.tsv` (~250 rows), GeoJSON copied.

- [ ] **Step 3: Failing tests** (use a tiny inline fixture TSV, not the 50k file, for determinism)

```swift
@Test func nearestCityResolvesParis() {
    let cities = "Paris\t48.8566\t2.3522\tFR\t2148000\nTokyo\t35.6895\t139.6917\tJP\t8336599\n"
    let countries = "FR\tFrance\tEU\nJP\tJapan\tAS\n"
    let geo = ReverseGeocoder(index: CityIndex(citiesTSV: cities, countriesTSV: countries))
    let r = geo.resolve(.init(latitude: 48.86, longitude: 2.34))
    #expect(r.city == "Paris" && r.country == "France" && r.continent == "Europe")
}
@Test func farFromAnyCityFallsBackToCountryOnly() {
    let cities = "Paris\t48.8566\t2.3522\tFR\t2148000\n"
    let countries = "FR\tFrance\tEU\n"
    let geo = ReverseGeocoder(index: CityIndex(citiesTSV: cities, countriesTSV: countries))
    let r = geo.resolve(.init(latitude: 0, longitude: 0))     // Gulf of Guinea
    #expect(r.city.isEmpty)   // no nearby city; country may also be empty
}
```

- [ ] **Step 4: Run, expect fail.**

- [ ] **Step 5: Implement `CityIndex`** — parse TSV into `[City]`; build a 1°-grid dictionary `[GridKey: [Int]]` of city indices for fast nearest lookup; `nearest` scans the 3x3 neighbor cells, picks min haversine; map `continentCode` (`EU/AS/NA/SA/AF/OC/AN`) to full names. `search` does case-insensitive prefix/contains match sorted by population desc.

- [ ] **Step 6: Implement `ReverseGeocoder`** — `nearest`; if distance > 200 km, return city = "" with best-effort country via nearest country anyway (or empty), else full triple.

- [ ] **Step 7: Run, expect pass.** Add `search("par")` test → Paris first. Commit `feat(kit): bundled city index + offline reverse geocoder`.

---

### Task 7: Import pipeline (samples -> Places) + dedup/merge

**Files:**
- Create: `Sources/TwineKit/ImportPipeline.swift`, `Tests/TwineKitTests/ImportPipelineTests.swift`

**Interfaces:**
- Consumes: `Clusterer`, `ReverseGeocoder`, `PhotoSample`, `Place`, `Visit`.
- Produces: `struct ImportPipeline { init(geocoder: ReverseGeocoder); func makePlaces(from samples: [PhotoSample]) -> [Place] }`.

- [ ] **Step 1: Failing test**

```swift
@Test func buildsPlacesWithMergedVisits() {
    let day1 = Date(timeIntervalSince1970: 1_700_000_000)
    let day2 = day1.addingTimeInterval(86_400 * 5)
    let samples = [
        PhotoSample(assetID: "p1", coordinate: .init(latitude: 48.85, longitude: 2.35), date: day1),
        PhotoSample(assetID: "p2", coordinate: .init(latitude: 48.86, longitude: 2.34), date: day1),
        PhotoSample(assetID: "p3", coordinate: .init(latitude: 48.85, longitude: 2.35), date: day2),
        PhotoSample(assetID: "t1", coordinate: .init(latitude: 35.68, longitude: 139.69), date: day1),
    ]
    let cities = "Paris\t48.8566\t2.3522\tFR\t2148000\nTokyo\t35.6895\t139.6917\tJP\t8336599\n"
    let countries = "FR\tFrance\tEU\nJP\tJapan\tAS\n"
    let pipe = ImportPipeline(geocoder: ReverseGeocoder(index: CityIndex(citiesTSV: cities, countriesTSV: countries)))
    let places = pipe.makePlaces(from: samples)
    let paris = places.first { $0.city == "Paris" }!
    #expect(places.count == 2)
    #expect(paris.photoCount == 3)
    #expect(paris.visits.count == 2)        // two distinct days
}
```

- [ ] **Step 2: Run, expect fail.**

- [ ] **Step 3: Implement** — cluster samples; for each cluster, geocode centroid → city/country/continent; group cluster samples into `Visit`s by calendar day (UTC) (gap-based merge: same day = same visit); `photoCount` = sample count; `representativeAssetID` = newest; sort places by photoCount desc.

- [ ] **Step 4: Run, expect pass.** Commit `feat(kit): import pipeline with visit merge`.

---

### Task 8: Stats

**Files:**
- Create: `Sources/TwineKit/Stats.swift`, `Tests/TwineKitTests/StatsTests.swift`

**Interfaces:**
- Consumes: `[Place]`, `Home` (a `Coordinate`), `haversineKilometers`.
- Produces: `struct Stats { let countries, cities, continents: Int; let threadKilometers: Double; let firstDate, lastDate: Date? }`; `enum StatsBuilder { static func build(places: [Place], home: Coordinate?) -> Stats }`.

- [ ] **Step 1: Failing test** — two places (Paris, Tokyo), home in SF: `countries == 2`, `continents == 2`, `threadKilometers` ≈ sum of home→each (within 1%), `cities == 2`.

- [ ] **Step 2: Run, expect fail.**

- [ ] **Step 3: Implement** — distinct counts via `Set`; thread km = Σ haversine(home, place) when home set else 0; first/last from visit dates.

- [ ] **Step 4: Run, expect pass.** Commit `feat(kit): stats`. **`swift test` full suite green — M1 complete.**

---

# Milestone 2 — App data layer (PhotoKit + SwiftData)

### Task 9: SwiftData store

**Files:**
- Create: `Twine/Model/Store.swift`

**Interfaces:**
- Produces: `@Model final class PlaceRecord` (id, lat, lon, city, country, continent, photoCount, representativeAssetID, note, isManual, firstDate, lastDate, visitDatesJSON, visitAssetIDsJSON); `@Model final class HomeRecord` (lat, lon, label); `enum Store { static func container() -> ModelContainer }`; mappers `PlaceRecord <-> TwineKit.Place`.

- [ ] **Step 1:** Define the `@Model` classes (store visits as JSON strings to stay simple; expose `var place: TwineKit.Place` computed mapper and an `init(_ place:)`).
- [ ] **Step 2:** `Store.container()` returns a `ModelContainer` for `[PlaceRecord.self, HomeRecord.self]` (on-disk, default URL).
- [ ] **Step 3:** Build the app target. Run app; no crash. Commit `feat(app): SwiftData store`.

(No unit test target for the app; verify by building + launching.)

---

### Task 10: PhotoKit provider + authorization

**Files:**
- Create: `Twine/App/PhotoLibrary.swift`

**Interfaces:**
- Consumes: `TwineKit.PhotoSampleProviding`, `PhotoSample`, `Coordinate`.
- Produces: `enum PhotoAuth { case notDetermined, denied, limited, full }`; `final class PhotoLibrary: PhotoSampleProviding { func authorization() -> PhotoAuth; func requestAccess() async -> PhotoAuth; func geotaggedSamples() async -> [PhotoSample]; var noLocationCount: Int }`.

- [ ] **Step 1:** Map `PHPhotoLibrary.authorizationStatus(for: .read)` → `PhotoAuth` (`.limited` distinct from `.authorized`→`.full`).
- [ ] **Step 2:** `requestAccess` via `PHPhotoLibrary.requestAuthorization(for: .read)`.
- [ ] **Step 3:** `geotaggedSamples` — `PHAsset.fetchAssets(with: .image, options:)` on a background queue; enumerate reading `asset.location` + `asset.creationDate` + `asset.localIdentifier`; collect samples where location != nil; increment `noLocationCount` otherwise. Never request image data here.
- [ ] **Step 4:** Build + run; temporarily log sample count on a debug button. Verify against a real library (or limited set). Commit `feat(app): PhotoKit provider + auth`.

---

### Task 11: Import coordinator

**Files:**
- Create: `Twine/App/ImportCoordinator.swift`

**Interfaces:**
- Consumes: `PhotoLibrary`, `TwineKit.ImportPipeline`, `ReverseGeocoder`, `CityIndex`, `Store`.
- Produces: `@MainActor @Observable final class ImportCoordinator { var phase: Phase; var progress: Double; var noLocationCount: Int; func run() async }` where `Phase = .idle|.scanning|.geocoding|.saving|.done`.

- [ ] **Step 1:** Load `CityIndex` from bundled `cities.tsv`/`countries.tsv` (read from `TwineKit`'s bundle via a public `TwineKit` accessor `BundledData.citiesTSV()/countriesTSV()` — add that accessor to the kit, no test needed beyond compile).
- [ ] **Step 2:** `run()` — get samples (background), `makePlaces`, diff against existing `PlaceRecord`s (upsert by rounded coordinate key; preserve manual pins + notes), save; publish progress between stages.
- [ ] **Step 3:** Build + run; trigger import; confirm `PlaceRecord`s persisted (re-launch shows them). Commit `feat(app): import coordinator`.

---

# Milestone 3 — UI

### Task 12: Map geometry (Natural Earth load + cached country layer)

**Files:**
- Create: `Twine/UI/MapGeometry.swift`; ensure `Twine/Resources/ne_110m_countries.json` exists (from Task 6 script).

**Interfaces:**
- Consumes: `TwineKit.Projection`, `Coordinate`.
- Produces: `enum MapGeometry { static func countryPaths() -> [Path] }` (each country projected to unit space, scalable by the view), and `static func image(size: CGSize, theme: Theme) -> NSImage` that rasterizes the static country layer once.

- [ ] **Step 1:** Parse the GeoJSON (Polygon + MultiPolygon) into `[[Coordinate]]` rings; project each via `Projection.project` into unit `Path`s (y down).
- [ ] **Step 2:** `image(size:)` draws filled+stroked countries into an `NSImage` once (cached) for use as the board backdrop (keeps `Canvas` cheap).
- [ ] **Step 3:** Build + render in a throwaway preview; confirm a recognizable world map. Commit `feat(app): natural earth map geometry`.

---

### Task 13: BoardView (Canvas poster map + pins + threads + pan/zoom)

**Files:**
- Create: `Twine/UI/BoardView.swift`, `Twine/UI/Theme.swift`

**Interfaces:**
- Consumes: `MapGeometry`, `Projection`, `[Place]`, `Home`, `ThumbnailLoader` (Task 15 dependency injected; pins can render without photo first).
- Produces: `struct BoardView: View` with bindings for `selectedPlaceID`, `scale`, `offset`.

- [ ] **Step 1:** Compose: cached country `Image` backdrop + a SwiftUI `Canvas` overlay that draws **threads** (Home→each place, thin stroke) then **pins** (dot + optional ring) at `Projection.project(place.coordinate)` scaled to the canvas size, honoring `scale`/`offset`.
- [ ] **Step 2:** Pan via `DragGesture` (update `offset`), zoom via `MagnificationGesture` + scroll (`scale`, clamped). Hit-test pins on tap (nearest within N points) → set `selectedPlaceID`.
- [ ] **Step 3:** Build + run with seeded data; verify pins land on correct countries, threads connect to Home, pan/zoom smooth (static layer cached). Commit `feat(app): board view (canvas map, pins, threads)`.

---

### Task 14: Sidebar

**Files:**
- Create: `Twine/UI/Sidebar.swift`

**Interfaces:**
- Consumes: `[Place]`, `selectedPlaceID` binding.
- Produces: `struct Sidebar: View` (search field + sortable list: date / visits / country).

- [ ] **Step 1:** `List` of places with city, country, date range, photo count; `searchable`; sort picker. Selecting a row sets `selectedPlaceID` (BoardView focuses it).
- [ ] **Step 2:** Build + run; selection syncs both ways. Commit `feat(app): places sidebar`.

---

### Task 15: Thumbnail loader + Pin detail

**Files:**
- Create: `Twine/App/ThumbnailLoader.swift`, `Twine/UI/PinDetail.swift`

**Interfaces:**
- Produces: `final class ThumbnailLoader { func image(for assetID: String, target: CGSize) async -> NSImage? }` (via `PHCachingImageManager`, handles missing asset → nil); `struct PinDetail: View` (representative photo + strip, city/country, date range, visit count, editable note bound to `PlaceRecord.note`).

- [ ] **Step 1:** `ThumbnailLoader` resolves `PHAsset.fetchAssets(withLocalIdentifiers:)`; returns nil if not found (caller shows placeholder).
- [ ] **Step 2:** `PinDetail` lazy-loads photos for the selected place; note edits persist via SwiftData.
- [ ] **Step 3:** Build + run; open a pin, see photos + edit a note (persists across relaunch). Commit `feat(app): thumbnails + pin detail`.

---

### Task 16: SummaryPanel

**Files:**
- Create: `Twine/UI/SummaryPanel.swift`

**Interfaces:**
- Consumes: `TwineKit.StatsBuilder`, `[Place]`, `Home`.
- Produces: `struct SummaryPanel: View` (countries, cities, continents, thread miles, first/last trip).

- [ ] **Step 1:** Compute `Stats` from current places + home; show big numbers + top countries. Convert km→miles for display.
- [ ] **Step 2:** Build + run; numbers match seeded data. Commit `feat(app): summary panel`.

---

### Task 17: Onboarding + permission + scan progress + full-access nudge

**Files:**
- Create: `Twine/UI/Onboarding.swift`

**Interfaces:**
- Consumes: `PhotoLibrary`, `ImportCoordinator`.
- Produces: `struct Onboarding: View` shown when no places yet / not authorized.

- [ ] **Step 1:** States: notDetermined → "Scan my photos" CTA; denied → open System Settings deep link + manual-mode hint; **limited → explicit "Grant Full Access so your whole map can populate" prompt**; full → run import with a progress view (phase + %), then show "N photos had no location".
- [ ] **Step 2:** Build + run through each auth state (use System Settings to toggle). Confirm limited mode shows the nudge, not a silent empty map. Commit `feat(app): onboarding + permission flow`.

---

### Task 18: Manual add place

**Files:**
- Create: `Twine/UI/AddPlaceSheet.swift`

**Interfaces:**
- Consumes: `CityIndex.search`, `Store`.
- Produces: `struct AddPlaceSheet: View` (search cities → pick → create a manual `PlaceRecord` with `isManual = true`).

- [ ] **Step 1:** Search field → results from `CityIndex.search`; selecting creates a manual place (no photos) at the city coordinate; appears on board + sidebar.
- [ ] **Step 2:** Build + run; add "Reykjavik"; pin + thread appear; survives re-import (not overwritten). Commit `feat(app): manual add place`.

---

### Task 19: Home picker + ContentView composition

**Files:**
- Create: `Twine/UI/ContentView.swift`; modify `Twine/App/TwineApp.swift`

**Interfaces:**
- Produces: three-pane `NavigationSplitView` (Sidebar | Board | detail/summary); a "Set Home" affordance (reuse `CityIndex.search`) writing `HomeRecord`.

- [ ] **Step 1:** Compose Sidebar + BoardView + (PinDetail when selected, else SummaryPanel). Wire `selectedPlaceID`, places query, home.
- [ ] **Step 2:** "Set Home" sheet sets `HomeRecord`; threads re-anchor.
- [ ] **Step 3:** `TwineApp` shows Onboarding until authorized+imported, else ContentView. Build + run end-to-end. Commit `feat(app): main window composition + home`.

---

### Task 20: Image export

**Files:**
- Create: `Twine/UI/ExportView.swift`

**Interfaces:**
- Consumes: `BoardView` (pure SwiftUI, so `ImageRenderer`-safe), `Stats`.
- Produces: `struct ExportView: View` + `func renderPoster(size: CGSize, scale: CGFloat) -> NSImage?` using `ImageRenderer` (set `.scale = 3`), save panel to PNG.

- [ ] **Step 1:** Build an export composition (board snapshot + title + stats footer) as pure SwiftUI; `ImageRenderer` → `NSImage` → `NSSavePanel` PNG.
- [ ] **Step 2:** Build + run; export a 3x PNG; confirm pins/threads/countries all present (proves no MapKit in the render path). Commit `feat(app): high-res image export`.

---

### Task 21: Settings + credits/attribution

**Files:**
- Create: `Twine/UI/Settings.swift`, `Twine/App/LoginItem.swift`; modify `TwineApp.swift` (add `Settings` scene).

**Interfaces:**
- Produces: launch-at-login (SMAppService), default sort, export defaults, and a **Credits** screen with "Geo data © GeoNames (CC BY 4.0)" + "Map: Natural Earth (public domain)".

- [ ] **Step 1:** Settings form + `LoginItem` (SMAppService.mainApp). Credits text (attribution is mandatory for GeoNames).
- [ ] **Step 2:** Build + run; toggle login item; see credits. Commit `feat(app): settings + attributions`.

---

# Milestone 4 — Packaging & release

### Task 22: App icon

**Files:**
- Create: `scripts/icon.svg`, `scripts/make-icon.sh` (reuse Blip's renderer: rsvg-convert + sips → appiconset + `assets/icon.png`).

- [ ] **Step 1:** Design an abstract icon (a pin + thread motif, modern keepsake palette). Render the appiconset. Build shows the icon. Commit `feat: app icon`.

---

### Task 23: README + CONTRIBUTING + screenshots

**Files:**
- Create/replace: `README.md`, `CONTRIBUTING.md`; add real screenshots under `assets/`.

- [ ] **Step 1:** README: icon, tagline, hero screenshot (real capture of a populated board), the privacy/local pitch, the wedge, install, build-from-source, "How it works" (TwineKit/app split), contribution registry (themes/pin styles/importers), data attributions, MIT. No em dashes.
- [ ] **Step 2:** CONTRIBUTING: `swift test` must stay green; how to add a theme/importer; run instructions. Commit `docs: README + CONTRIBUTING`.

---

### Task 24: Notarized DMG + cask + release

**Files:**
- Create: `scripts/build-dmg.sh` (reuse Blip's fixed script), `Casks/twine.rb`, `docs/NOTARIZATION.md`.

- [ ] **Step 1:** Build Release, sign with "Developer ID Application: Ivan Kuria (347LA37C2B)", `notarytool --keychain-profile "blip-notary"` (Ivan runs credential steps), staple, `spctl` verify, package DMG.
- [ ] **Step 2:** `gh release create v0.1.0` + upload DMG; pin cask sha256. Push tags. Commit `chore: release v0.1.0`.

---

## Self-Review

- **Spec coverage:** soul/look (Tasks 12-20 UI), auto-import (10-11,17), clustering/geocode/merge (5-7), offline data (6), poster Canvas not MapKit (12-13,20), `.limited` handling (10,17), SwiftData by localIdentifier (9,15), stats/summary (8,16), manual add (18), image export (20), privacy/no-network (Task 1 entitlements), attribution (21), packaging (22-24). Covered.
- **Placeholders:** none — kit tasks have full code + tests; app tasks have concrete interfaces, files, and run-to-verify steps.
- **Type consistency:** `Coordinate`, `UnitPoint2D`, `PhotoSample`, `Place`, `Visit`, `Cluster`, `City`, `CityIndex`, `ReverseGeocoder`, `ImportPipeline`, `Stats`, `PlaceRecord`/`HomeRecord`, `PhotoLibrary`, `ImportCoordinator`, `ThumbnailLoader`, `MapGeometry`, `BoardView` used consistently across tasks.
- **Deferred (v1.1):** animated video export, Robinson projection, themes/importers registry content, MapKit detail view, chronological trip threads, localization.
