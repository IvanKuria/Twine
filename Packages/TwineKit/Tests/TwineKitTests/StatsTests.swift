import Testing
import Foundation
@testable import TwineKit

@Suite("Stats")
struct StatsTests {

    // MARK: - Fixtures

    private let sf    = Coordinate(latitude: 37.7749, longitude: -122.4194)
    private let paris = Coordinate(latitude: 48.8566, longitude: 2.3522)
    private let tokyo = Coordinate(latitude: 35.6762, longitude: 139.6503)

    private let day0  = Date(timeIntervalSince1970: 1_700_000_000)
    private let day1  = Date(timeIntervalSince1970: 1_700_000_000 + 86_400)

    private var placeParis: Place {
        Place(
            coordinate: Coordinate(latitude: 48.8566, longitude: 2.3522),
            city: "Paris",
            country: "France",
            continent: "Europe",
            visits: [
                Visit(date: Date(timeIntervalSince1970: 1_700_000_000), assetIDs: ["p1"]),
                Visit(date: Date(timeIntervalSince1970: 1_700_000_000 + 86_400), assetIDs: ["p2"])
            ]
        )
    }

    private var placeTokyo: Place {
        Place(
            coordinate: Coordinate(latitude: 35.6762, longitude: 139.6503),
            city: "Tokyo",
            country: "Japan",
            continent: "Asia",
            visits: [
                Visit(date: Date(timeIntervalSince1970: 1_700_000_000 + 86_400 + 7_200), assetIDs: ["t1"])
            ]
        )
    }

    // MARK: - Two-place / home-set scenario

    @Test func countriesCitiesContinents() {
        let stats = StatsBuilder.build(places: [placeParis, placeTokyo], home: sf)
        #expect(stats.countries == 2)
        #expect(stats.cities == 2)
        #expect(stats.continents == 2)
    }

    @Test func threadKilometersWithHome() {
        let stats = StatsBuilder.build(places: [placeParis, placeTokyo], home: sf)
        let expected = haversineKilometers(sf, paris)
                     + haversineKilometers(sf, tokyo)
        #expect(abs(stats.threadKilometers - expected) < expected * 0.01)
    }

    @Test func firstAndLastDate() {
        let stats = StatsBuilder.build(places: [placeParis, placeTokyo], home: sf)
        #expect(stats.firstDate == day0)
        #expect(stats.lastDate == Date(timeIntervalSince1970: 1_700_000_000 + 86_400 + 7_200))
    }

    // MARK: - Nil home scenario

    @Test func threadKilometersNilHome() {
        let stats = StatsBuilder.build(places: [placeParis, placeTokyo], home: nil)
        #expect(stats.threadKilometers == 0)
    }

    // MARK: - Empty places scenario

    @Test func emptyPlaces() {
        let stats = StatsBuilder.build(places: [], home: sf)
        #expect(stats.countries == 0)
        #expect(stats.cities == 0)
        #expect(stats.continents == 0)
        #expect(stats.threadKilometers == 0)
        #expect(stats.firstDate == nil)
        #expect(stats.lastDate == nil)
    }

    // MARK: - Empty-string fields are ignored

    @Test func emptyStringFieldsAreIgnored() {
        let placeNoCountry = Place(
            coordinate: paris,
            city: "",
            country: "",
            continent: "",
            visits: [Visit(date: day0, assetIDs: [])]
        )
        let stats = StatsBuilder.build(places: [placeNoCountry], home: nil)
        #expect(stats.countries == 0)
        #expect(stats.cities == 0)
        #expect(stats.continents == 0)
    }
}
