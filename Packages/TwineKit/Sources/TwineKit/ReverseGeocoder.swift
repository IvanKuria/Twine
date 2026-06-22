import Foundation

/// Resolves a geographic coordinate to a human-readable city/country/continent triple.
///
/// If the nearest city in the index is farther than 200 km from `c`, `city` is returned
/// as an empty string. Country and continent are derived from the nearest city's country
/// code regardless of distance (best-effort).
public struct ReverseGeocoder: Sendable {

    public let index: CityIndex

    public init(index: CityIndex) {
        self.index = index
    }

    /// - Returns: `(city, country, continent)`.  `city` is `""` when the nearest city
    ///   is farther than 200 km; country/continent are best-effort (may also be empty).
    public func resolve(_ c: Coordinate) -> (city: String, country: String, continent: String) {
        guard let nearest = index.nearest(to: c) else {
            return (city: "", country: "", continent: "")
        }

        let distance = haversineKilometers(c, nearest.city.coordinate)
        let cityName = distance <= 200.0 ? nearest.city.name : ""

        return (city: cityName, country: nearest.country, continent: nearest.continent)
    }
}
