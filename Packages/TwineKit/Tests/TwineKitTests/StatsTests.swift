import XCTest
@testable import TwineKit

final class StatsTests: XCTestCase {

    // MARK: - Fixtures

    private static let sf    = Coordinate(latitude: 37.7749, longitude: -122.4194)
    private static let paris = Coordinate(latitude: 48.8566, longitude: 2.3522)
    private static let tokyo = Coordinate(latitude: 35.6762, longitude: 139.6503)

    private static let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    private static let day1 = day0 + 86_400

    private static let placeParis = Place(
        coordinate: paris,
        city: "Paris",
        country: "France",
        continent: "Europe",
        visits: [Visit(date: day0, assetIDs: ["p1"]), Visit(date: day1, assetIDs: ["p2"])]
    )

    private static let placeTokyo = Place(
        coordinate: tokyo,
        city: "Tokyo",
        country: "Japan",
        continent: "Asia",
        visits: [Visit(date: day1 + 7_200, assetIDs: ["t1"])]
    )

    // MARK: - Two-place / home-set scenario

    func testCountriesCitiesContinents() {
        let stats = StatsBuilder.build(places: [Self.placeParis, Self.placeTokyo], home: Self.sf)
        XCTAssertEqual(stats.countries, 2)
        XCTAssertEqual(stats.cities, 2)
        XCTAssertEqual(stats.continents, 2)
    }

    func testThreadKilometersWithHome() {
        let stats = StatsBuilder.build(places: [Self.placeParis, Self.placeTokyo], home: Self.sf)
        let expected = haversineKilometers(Self.sf, Self.paris)
                     + haversineKilometers(Self.sf, Self.tokyo)
        XCTAssertEqual(stats.threadKilometers, expected, accuracy: expected * 0.01,
                       "threadKilometers should be within 1% of home→Paris + home→Tokyo")
    }

    func testFirstAndLastDate() {
        let stats = StatsBuilder.build(places: [Self.placeParis, Self.placeTokyo], home: Self.sf)
        XCTAssertEqual(stats.firstDate, Self.day0)
        XCTAssertEqual(stats.lastDate, Self.day1 + 7_200)
    }

    // MARK: - Nil home scenario

    func testThreadKilometersNilHome() {
        let stats = StatsBuilder.build(places: [Self.placeParis, Self.placeTokyo], home: nil)
        XCTAssertEqual(stats.threadKilometers, 0)
    }

    // MARK: - Empty places scenario

    func testEmptyPlaces() {
        let stats = StatsBuilder.build(places: [], home: Self.sf)
        XCTAssertEqual(stats.countries, 0)
        XCTAssertEqual(stats.cities, 0)
        XCTAssertEqual(stats.continents, 0)
        XCTAssertEqual(stats.threadKilometers, 0)
        XCTAssertNil(stats.firstDate)
        XCTAssertNil(stats.lastDate)
    }

    // MARK: - Empty-string fields are ignored

    func testEmptyStringFieldsAreIgnored() {
        let placeNoCountry = Place(
            coordinate: Self.paris,
            city: "",
            country: "",
            continent: "",
            visits: [Visit(date: Self.day0, assetIDs: [])]
        )
        let stats = StatsBuilder.build(places: [placeNoCountry], home: nil)
        XCTAssertEqual(stats.countries, 0)
        XCTAssertEqual(stats.cities, 0)
        XCTAssertEqual(stats.continents, 0)
    }
}
