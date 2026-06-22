import Testing
@testable import TwineKit

// Inline fixture TSV strings — tiny, deterministic, no file I/O.
private let fixtureCities = "Paris\t48.8566\t2.3522\tFR\t2148000\nTokyo\t35.6895\t139.6917\tJP\t8336599\n"
private let fixtureCountries = "FR\tFrance\tEU\nJP\tJapan\tAS\n"

@Test func nearestCityResolvesParis() {
    let geo = ReverseGeocoder(index: CityIndex(citiesTSV: fixtureCities, countriesTSV: fixtureCountries))
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

@Test func searchReturnsParisFirstForParQuery() {
    let geo = ReverseGeocoder(index: CityIndex(citiesTSV: fixtureCities, countriesTSV: fixtureCountries))
    let results = geo.index.search("par", limit: 10)
    #expect(results.first?.name == "Paris")
}

// Regression test: CityIndex.nearest(to:) must correctly find cities that sit
// just across the antimeridian (lon ≈ −179 when queried from lon ≈ +179).
// Before the fix the neighbor scan produced raw lon cells 180/181 which never
// matched grid keys stored at −180/−179, so the correct city was silently skipped.
@Test func nearestCityAcrossAntimeridianIsFound() {
    // Apia (Samoa-like): lon ≈ −171, well into the western side of the antimeridian.
    // We place a synthetic city at lon −179.5 and query from lon +179.5 (~1° away).
    // A far-away decoy city (Paris, lon ≈ +2) must NOT win.
    let cities = "NearAntimeridian\t-14.0\t-179.5\tWS\t40000\nParis\t48.8566\t2.3522\tFR\t2148000\n"
    let countries = "WS\tSamoa\tOC\nFR\tFrance\tEU\n"
    let index = CityIndex(citiesTSV: cities, countriesTSV: countries)
    // Query from lon +179.5 — only ~1° of longitude from lon −179.5 across the antimeridian.
    let result = index.nearest(to: .init(latitude: -14.0, longitude: 179.5))
    #expect(result?.city.name == "NearAntimeridian",
            "Expected the antimeridian-adjacent city, got: \(result?.city.name ?? "nil")")
}
