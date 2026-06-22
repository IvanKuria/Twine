# Twine — Design Spec

> A native macOS keepsake of everywhere you've been: a poster-style world map where pins for your travels are connected by thread to Home, seeded automatically from your photo library — 100% local.

**Status:** Approved design, pre-implementation.
**Date:** 2026-06-22
**Working name:** Twine (alternates considered: *Spool*, *Wanderwall*).

---

## 1. Soul & Positioning

- **Soul:** A **memory wall** — look *back* on where you've been. It is a keepsake artifact you'd display and share, not a trip planner or a logger.
- **Visual direction:** **Modern keepsake** — a clean, Apple-native "poster" world map with tasteful real pins, thin thread to a Home pin, and framed photo thumbnails. Warm but premium and timeless (not full skeuomorphic corkboard, not sterile Google-map).
- **Three-pane layout** (the data-viz framing the user liked): left **Places sidebar**, center **map/board**, right **summary/stats** (or summary as an overlay panel — see §6).

### Competitive wedge (verified)
The travel-map category is crowded but our **specific four-way combination is unoccupied**:
1. **Native macOS** (the entire OSS field is web/JS/Python; *zero* native Swift competitors on GitHub).
2. **Retroactive auto-import** from the Photos library's GPS (reconstruct 10 years in seconds, zero typing).
3. **Keepsake string-to-Home poster** aesthetic (the viral visual hook).
4. **Shareable image/video export** of the board.

Closest rival: **Passage** (native Mac, does photo-GPS import) — but it produces *per-trip flight-arc cards on a photo*, not a persistent cumulative life-map. We beat it on **identity**: the persistent keepsake wall + **free, open-source, 100% local, no account** (vs. Passage's paid passes). Day One, Polarsteps, Visited/Been, Wanderlog, Apple Photos "Places", Mult.dev/PictraMap each miss two or more of the four.

**Biggest risks:** (a) Passage adds a "lifetime board" mode — mitigate by owning the keepsake identity + OSS/local; (b) the custom map is the largest engineering line item — do not underestimate it.

---

## 2. Goals & Non-Goals

**Goals**
- A beautiful, screenshot-worthy keepsake that populates with near-zero effort.
- 100% local & private: read-only Photos access, no network entitlement, no account, no cloud.
- Reliable by construction: no external/rate-limited APIs (the failure that killed a prior project). All map + geocoding data is bundled.
- Attract GitHub stars **and contributors** (clean registry surface) + serve as a FAANG-resume systems project.

**Non-Goals (v1)**
- Trip planning / bucket list / collaboration / social feed.
- Live GPS tracking.
- iCloud sync or multi-device.
- Deep, infinite map zoom (a wall artifact needs world/continent + city pins, not street level).

---

## 3. Architecture (Blip two-target pattern)

Two targets, mirroring the proven Blip/WaybackKit split:

### `TwineKit` — pure, unit-tested Swift package (no UI, no PhotoKit, no AppKit)
Owns all logic that can be tested deterministically. Photo metadata enters through a **protocol** (à la Blip's `PasteboardReading`) so tests inject fakes.

Responsibilities:
- **Data model** (plain value types): `PhotoSample` (coordinate + date + assetID), `Place`, `Pin`, `Home`, `Trip`/thread, `MapProjection`.
- **Clustering:** group nearby `PhotoSample`s into one `Place` (so 50k photos don't make 50k overlapping pins).
- **Offline reverse-geocoder:** nearest-city lookup against a bundled GeoNames SQLite (no network).
- **Stats:** counts (countries, cities, continents), great-circle distances (haversine), total "thread miles."
- **Dedup / date-range merge:** repeated visits to a city merge into one `Place` with a visit list / date range.
- **Projection math:** lon/lat → normalized board coordinates (equirectangular v1).

### `Twine` — thin SwiftUI + AppKit app
- **PhotoKit access** (read-only): authorization handling, background metadata scan, on-demand thumbnails.
- **Map/board renderer:** custom SwiftUI `Canvas` poster map (see §5), pins + thread overlay, pan/zoom, hit-testing.
- **Pin detail:** photos (lazy thumbnails), dates, editable note/title.
- **Sidebar + summary** panels.
- **Export pipeline:** image (v1) and animated thread-draw video (v1.1).
- **Persistence** (SwiftData), settings, optional launch-at-login.

---

## 4. Data Flow

1. **First run → Photos permission.** Request read access (`accessLevel: .read`). **Explicitly detect `.limited`** and show a "Grant Full Access so your whole map can populate" prompt — the zero-typing pitch dies silently in limited mode (must-do).
2. **Scan (background queue).** `PHAsset.fetchAssets`, read **`asset.location` directly** (a `CLLocation`) + `asset.creationDate`. Never request image *data* in the scan pass (avoids the export-time GPS-stripping gotcha and keeps the sweep fast). Skip nil-location assets; surface an honest "*N photos had no location*" count.
3. **Cluster** samples → `Place`s; **reverse-geocode** each cluster (bundled GeoNames) → city/country; **merge** repeat visits into date ranges.
4. **Set Home** (search a place). Threads draw Home → each `Place`. (Optional chronological "trip" threads = later.)
5. **Browse:** sidebar lists places (sort by date / visits / country); summary shows totals; click a pin → detail with lazily-loaded thumbnails (`PHCachingImageManager`, visible pins only).
6. **Manual add:** search a place → drop a pin (for trips with no geotagged photos).
7. **Export:** render the board to a high-res image (and later an animated video).

---

## 5. The Map (largest engineering item — feasibility-driven decisions)

- **Render the hero board in SwiftUI `Canvas`, NOT MapKit.** Required for the poster aesthetic *and* because `ImageRenderer` cannot export `NSViewRepresentable`/MapKit content (it would export blank). This is a hard constraint.
- **Country shapes:** bundle **Natural Earth 1:110m admin-0 countries** (public domain, no attribution required). Parse GeoJSON polygons → project → `Path` → fill/stroke.
- **Projection:** **equirectangular** for v1 (`x = (lon+180)/360·W`, `y = (90−lat)/180·H`). Robinson later (needs a lookup-table interpolation).
- **Performance:** simplify polygons (Douglas–Peucker) at bundle time; **draw the static country layer once into a cached image**, keep only **pins + threads** live in `Canvas`. If `Canvas` still stutters, fall back to a Metal/`CAShapeLayer` path layer.
- **Optional later:** a MapKit "real map" view *inside the pin detail* only (cheap, and keeps the poster as the signature surface).

---

## 6. UI Surfaces

- **Board (center):** poster map, pins (with optional framed representative photo), thread to Home. Pan/zoom; click pin → detail.
- **Places sidebar (left):** searchable, sortable list; selecting an item focuses its pin.
- **Summary (right or top-overlay):** countries, cities, continents, total thread miles, first/last trip. Final placement decided during UI build; content is fixed here.
- **Pin detail:** representative photo + photo strip, city/country, date range, visit count, editable title & note.
- **Onboarding:** permission flow + scan progress + the "full access" nudge.
- **Settings:** launch-at-login, default sort, export defaults, attribution/credits.
- **Export sheet:** choose size/theme; render image (v1) / video (v1.1).

---

## 7. Persistence

- **SwiftData** for `Place`, notes, custom titles/colors, the `Home` pin, manual pins, and each photo's **`PHAsset.localIdentifier`** + cached coordinate.
- **Never copy photos** — reference by `localIdentifier`, load thumbnails on demand. Keeps the app tiny and genuinely "local, no duplication."
- **Resilience:** `localIdentifier` can change (re-import/library migration). On "asset not found," keep the pin from the **cached coordinate** and show a placeholder — never crash.

---

## 8. Bundled Data & Licensing

- **Natural Earth 1:110m** country polygons — **public domain** (no attribution required).
- **GeoNames `cities5000`** (~50k cities) as SQLite for offline reverse-geocode — **CC-BY 4.0**; **must show attribution** ("Geo data © GeoNames, CC BY 4.0") in an About/Credits screen.
- No `CLGeocoder` (network-backed, rate-limited) — bundled GeoNames only.

---

## 9. Error Handling

- **No / denied Photos permission:** app still works in manual mode; clear path to re-grant.
- **Limited-library mode:** explicit "grant full access" prompt; do not silently degrade.
- **Photos without GPS:** skipped, counted, surfaced honestly.
- **Geocode miss** (coordinate far from any city): fall back to country-level label.
- **Large libraries (50k+):** background scan with progress; metadata-only sweep; thumbnails lazily.
- **Missing asset on load:** placeholder + cached coordinate, no crash.

---

## 10. Testing

`TwineKit` is pure → unit-tested with injected fake photo metadata (Blip's `FakePasteboard` pattern):
- Clustering (proximity grouping; singletons; dense city).
- Reverse-geocode nearest-city correctness + country fallback.
- Stats: country/city/continent counts; haversine distance; thread-mile totals.
- Dedup / date-range merge for repeat visits.
- Projection: lon/lat → normalized coordinates round-trips at known points.

UI changes verified by running the app.

---

## 11. Contribution Surface (for stars + contributors)

In-repo, PR-able registries (the contributor magnet):
- **Map themes / poster styles** (color ramps, paper textures).
- **Pin & thread styles.**
- **Importers:** GPX, Google Takeout, Swarm/Foursquare export (each a self-contained importer).
- **Localization.**

Each is a low-skill, high-value PR that grows the contributor graph.

---

## 12. Tech Stack

- Swift 6, SwiftUI + AppKit, macOS 14+.
- XcodeGen (`project.yml` → generated `.xcodeproj`), Xcode 26.
- SwiftData (persistence), PhotoKit (read-only), `Canvas`/Core Graphics (map), `ImageRenderer` (image export), `AVAssetWriter` (video export, v1.1).
- App Sandbox; **no network entitlement**; `NSPhotoLibraryUsageDescription`.
- Distribution: Developer-ID signed + notarized DMG (Blip pipeline); Homebrew cask later. MIT license.

---

## 13. Scope: v1 vs. later

**v1 (this plan):**
- Photos auto-import (with full/limited-access handling) + manual add.
- Clustering + offline reverse-geocode + dedup/date-merge.
- Poster `Canvas` map (equirectangular) + pins + thread-to-Home.
- Sidebar + summary + pin detail (photos/dates/note).
- SwiftData persistence.
- **Image export.**
- Notarized DMG, README, icon.

**Later (v1.1+):**
- **Animated thread-draw video export** (the viral artifact).
- Robinson projection; map themes; importers (GPX/Takeout/Swarm); MapKit detail view; chronological trip threads; localization.

---

## 14. Open Decisions (non-blocking)

- Final name (Twine vs alternates).
- Summary panel placement (right pane vs. top overlay) — decided during UI build.
- Pin label density / collision handling at world zoom — tuned during UI build.
