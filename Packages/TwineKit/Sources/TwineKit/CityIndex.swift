import Foundation

// MARK: - City

public struct City: Sendable, Equatable {
    public let name: String
    public let coordinate: Coordinate
    public let countryCode: String
    public let population: Int

    public init(name: String, coordinate: Coordinate, countryCode: String, population: Int) {
        self.name = name
        self.coordinate = coordinate
        self.countryCode = countryCode
        self.population = population
    }
}

// MARK: - CityIndex

public struct CityIndex: Sendable {

    // MARK: Types

    private struct GridKey: Hashable {
        let latCell: Int
        let lonCell: Int
    }

    private struct CountryInfo {
        let name: String
        let continentCode: String
    }

    // MARK: Storage

    private let cities: [City]
    private let grid: [GridKey: [Int]]            // gridKey → indices into `cities`
    private let countryMap: [String: CountryInfo]  // ISO 2-letter code → info

    // MARK: Continent name mapping

    private static let continentNames: [String: String] = [
        "EU": "Europe",
        "AS": "Asia",
        "NA": "North America",
        "SA": "South America",
        "AF": "Africa",
        "OC": "Oceania",
        "AN": "Antarctica"
    ]

    // MARK: Init

    public init(citiesTSV: String, countriesTSV: String) {
        var parsedCities: [City] = []

        for line in citiesTSV.split(separator: "\n", omittingEmptySubsequences: true) {
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 5,
                  let lat = Double(cols[1]),
                  let lon = Double(cols[2]),
                  let pop = Int(cols[4]) else { continue }
            let city = City(
                name: String(cols[0]),
                coordinate: Coordinate(latitude: lat, longitude: lon),
                countryCode: String(cols[3]),
                population: pop
            )
            parsedCities.append(city)
        }

        var parsedCountries: [String: CountryInfo] = [:]
        for line in countriesTSV.split(separator: "\n", omittingEmptySubsequences: true) {
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 3 else { continue }
            let code = String(cols[0])
            parsedCountries[code] = CountryInfo(name: String(cols[1]), continentCode: String(cols[2]))
        }

        // Build 1°-grid index
        var g: [GridKey: [Int]] = [:]
        g.reserveCapacity(parsedCities.count / 4)
        for (idx, city) in parsedCities.enumerated() {
            let key = GridKey(
                latCell: Int(floor(city.coordinate.latitude)),
                lonCell: Int(floor(city.coordinate.longitude))
            )
            g[key, default: []].append(idx)
        }

        self.cities = parsedCities
        self.grid = g
        self.countryMap = parsedCountries
    }

    // MARK: Nearest lookup

    /// Returns the nearest city (within any distance), plus its country name and continent name.
    public func nearest(to coord: Coordinate) -> (city: City, country: String, continent: String)? {
        guard !cities.isEmpty else { return nil }

        let baseLat = Int(floor(coord.latitude))
        let baseLon = Int(floor(coord.longitude))

        var bestIdx: Int? = nil
        var bestDist = Double.infinity

        for dLat in -1...1 {
            for dLon in -1...1 {
                let key = GridKey(latCell: baseLat + dLat, lonCell: baseLon + dLon)
                guard let indices = grid[key] else { continue }
                for idx in indices {
                    let d = haversineKilometers(coord, cities[idx].coordinate)
                    if d < bestDist {
                        bestDist = d
                        bestIdx = idx
                    }
                }
            }
        }

        // If 3x3 neighbourhood is empty, fall back to full scan (sparse regions).
        if bestIdx == nil {
            for (idx, city) in cities.enumerated() {
                let d = haversineKilometers(coord, city.coordinate)
                if d < bestDist {
                    bestDist = d
                    bestIdx = idx
                }
            }
        }

        guard let idx = bestIdx else { return nil }
        let city = cities[idx]
        let info = countryMap[city.countryCode]
        let countryName = info?.name ?? ""
        let continentName = info.flatMap { Self.continentNames[$0.continentCode] } ?? ""
        return (city: city, country: countryName, continent: continentName)
    }

    // MARK: Search

    /// Case-insensitive prefix-or-contains match, sorted by population descending.
    public func search(_ query: String, limit: Int) -> [City] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return cities
            .filter { $0.name.lowercased().hasPrefix(q) || $0.name.lowercased().contains(q) }
            .sorted { $0.population > $1.population }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - BundledData

public enum BundledData {
    public static func citiesTSV() throws -> String {
        guard let url = Bundle.module.url(forResource: "cities", withExtension: "tsv") else {
            throw BundledDataError.resourceNotFound("cities.tsv")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public static func countriesTSV() throws -> String {
        guard let url = Bundle.module.url(forResource: "countries", withExtension: "tsv") else {
            throw BundledDataError.resourceNotFound("countries.tsv")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

public enum BundledDataError: Error {
    case resourceNotFound(String)
}
