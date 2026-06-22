import SwiftUI
import TwineKit

// MARK: - PlaceSort

enum PlaceSort: String, CaseIterable {
    case recent      = "Recent"
    case mostVisited = "Most Visited"
    case country     = "Country"
}

// MARK: - Sidebar

struct Sidebar: View {

    // MARK: - Inputs

    let places: [Place]
    @Binding var selectedPlaceID: UUID?

    // MARK: - Private state

    @State private var query: String = ""
    @State private var sort: PlaceSort = .recent

    // MARK: - Derived data

    private var filteredSortedPlaces: [Place] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered: [Place] = q.isEmpty ? places : places.filter {
            $0.city.lowercased().contains(q) || $0.country.lowercased().contains(q)
        }

        switch sort {
        case .recent:
            return filtered.sorted {
                switch ($0.lastDate, $1.lastDate) {
                case let (a?, b?): return a > b
                case (_?, nil):    return true
                case (nil, _?):    return false
                case (nil, nil):   return $0.city < $1.city
                }
            }
        case .mostVisited:
            return filtered.sorted {
                $0.photoCount != $1.photoCount
                    ? $0.photoCount > $1.photoCount
                    : $0.city < $1.city
            }
        case .country:
            return filtered.sorted {
                $0.country != $1.country
                    ? $0.country < $1.country
                    : $0.city < $1.city
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Sort picker
            Picker("Sort", selection: $sort) {
                ForEach(PlaceSort.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            // Place list
            List(filteredSortedPlaces, selection: $selectedPlaceID) { place in
                PlaceRow(place: place)
                    .tag(place.id)
            }
            .listStyle(.sidebar)
            .searchable(text: $query, placement: .sidebar, prompt: "Search places")
        }
        .frame(minWidth: 220)
    }
}

// MARK: - PlaceRow

private struct PlaceRow: View {

    let place: Place

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    private var dateRangeLabel: String? {
        guard let first = place.firstDate else { return nil }
        let firstYear = Self.yearFormatter.string(from: first)
        if let last = place.lastDate, last > first {
            let lastYear = Self.yearFormatter.string(from: last)
            return firstYear == lastYear ? firstYear : "\(firstYear)–\(lastYear)"
        }
        return firstYear
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {

            // City + country stack
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(place.city)
                        .font(.headline)
                        .lineLimit(1)

                    if place.isManual {
                        Image(systemName: "hand.point.up")
                            .font(.caption2)
                            .foregroundStyle(Theme.pin)
                    }
                }

                Text(place.country)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let range = dateRangeLabel {
                    Text(range)
                        .font(Theme.labelFont)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Photo count badge
            if place.photoCount > 0 {
                Text("\(place.photoCount)")
                    .font(Theme.labelFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.pin.opacity(0.85), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

private struct SidebarPreview: View {
    @State private var selected: UUID? = nil

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private let samplePlaces: [Place] = {
        let paris = Place(
            coordinate: Coordinate(latitude: 48.857, longitude: 2.352),
            city: "Paris", country: "France", continent: "Europe",
            visits: [
                Visit(date: makeDate(year: 2019, month: 6, day: 10), assetIDs: ["a1", "a2"]),
                Visit(date: makeDate(year: 2022, month: 9, day: 3),  assetIDs: ["a3"])
            ],
            photoCount: 142,
            isManual: false
        )
        let tokyo = Place(
            coordinate: Coordinate(latitude: 35.682, longitude: 139.691),
            city: "Tokyo", country: "Japan", continent: "Asia",
            visits: [
                Visit(date: makeDate(year: 2023, month: 3, day: 18), assetIDs: ["b1"])
            ],
            photoCount: 87,
            isManual: false
        )
        let nairobi = Place(
            coordinate: Coordinate(latitude: -1.286, longitude: 36.818),
            city: "Nairobi", country: "Kenya", continent: "Africa",
            visits: [],
            photoCount: 0,
            isManual: true
        )
        let newYork = Place(
            coordinate: Coordinate(latitude: 40.713, longitude: -74.006),
            city: "New York", country: "USA", continent: "North America",
            visits: [
                Visit(date: makeDate(year: 2021, month: 11, day: 5), assetIDs: ["c1", "c2", "c3"])
            ],
            photoCount: 31,
            isManual: false
        )
        return [paris, tokyo, nairobi, newYork]
    }()

    var body: some View {
        Sidebar(places: samplePlaces, selectedPlaceID: $selected)
            .frame(width: 280, height: 480)
    }
}

#Preview("Sidebar") {
    SidebarPreview()
}
