import Foundation

public struct Stats: Sendable, Equatable {
    public let countries: Int
    public let cities: Int
    public let continents: Int
    public let threadKilometers: Double
    public let firstDate: Date?
    public let lastDate: Date?
}

public enum StatsBuilder {
    public static func build(places: [Place], home: Coordinate?) -> Stats {
        let countries   = Set(places.map(\.country).filter { !$0.isEmpty }).count
        let cities      = Set(places.map(\.city).filter { !$0.isEmpty }).count
        let continents  = Set(places.map(\.continent).filter { !$0.isEmpty }).count

        let threadKilometers: Double = home.map { h in
            places.reduce(0) { $0 + haversineKilometers(h, $1.coordinate) }
        } ?? 0

        let allDates = places.flatMap(\.visits).map(\.date)
        let firstDate = allDates.min()
        let lastDate  = allDates.max()

        return Stats(
            countries: countries,
            cities: cities,
            continents: continents,
            threadKilometers: threadKilometers,
            firstDate: firstDate,
            lastDate: lastDate
        )
    }
}
