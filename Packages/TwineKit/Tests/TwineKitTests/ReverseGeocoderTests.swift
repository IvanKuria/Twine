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

@Test func searchReturnsParisFistForParQuery() {
    let geo = ReverseGeocoder(index: CityIndex(citiesTSV: fixtureCities, countriesTSV: fixtureCountries))
    let results = geo.index.search("par", limit: 10)
    #expect(results.first?.name == "Paris")
}
