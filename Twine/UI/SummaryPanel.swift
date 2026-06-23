import SwiftUI
import TwineKit

// MARK: - SummaryPanel

struct SummaryPanel: View {

    // MARK: - Inputs

    let places: [Place]
    let home: Coordinate?

    // MARK: - Derived data

    private var stats: Stats {
        StatsBuilder.build(places: places, home: home)
    }

    /// Top countries by place count, up to 5, ignoring blank country strings.
    private var topCountries: [(country: String, count: Int)] {
        var tally: [String: Int] = [:]
        for place in places where !place.country.isEmpty {
            tally[place.country, default: 0] += 1
        }
        return tally
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(5)
            .map { (country: $0.key, count: $0.value) }
    }

    // MARK: - Formatters (shared, avoid per-call alloc)

    private static let groupingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    // MARK: - Helpers

    private func formatted(_ value: Double) -> String {
        Self.groupingFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func year(from date: Date?) -> String? {
        date.map { Self.yearFormatter.string(from: $0) }
    }

    // MARK: - Body

    var body: some View {
        if places.isEmpty {
            emptyState
        } else {
            cardContent
        }
    }

    // MARK: - Card content

    private var cardContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headline
                Divider()
                threadRow
                Divider()
                dateRangeRow
                if !topCountries.isEmpty {
                    Divider()
                    topCountriesSection
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Section: Big stat numbers

    private var headline: some View {
        HStack(spacing: 0) {
            statCell(value: stats.countries,   label: "Countries")
            statDivider
            statCell(value: stats.cities,      label: "Cities")
            statDivider
            statCell(value: stats.continents,  label: "Continents")
        }
    }

    private var statDivider: some View {
        Divider()
            .frame(height: 44)
            .padding(.horizontal, 4)
    }

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.home)
                .monospacedDigit()
            Text(label)
                .font(Theme.labelFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section: Thread distance

    private var threadRow: some View {
        let km    = stats.threadKilometers
        let miles = km * 0.621371
        let miStr = formatted(miles)
        let kmStr = formatted(km)

        return VStack(alignment: .leading, spacing: 3) {
            Label {
                Text("\(miStr) mi of thread")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "line.diagonal")
                    .foregroundStyle(Theme.thread)
            }

            Text("\(kmStr) km")
                .font(Theme.labelFont)
                .foregroundStyle(.secondary)
                .padding(.leading, 22)
        }
    }

    // MARK: - Section: Date range

    private var dateRangeRow: some View {
        HStack(spacing: 16) {
            dateCell(title: "First trip", year: year(from: stats.firstDate))
            Spacer()
            dateCell(title: "Latest", year: year(from: stats.lastDate))
        }
    }

    private func dateCell(title: String, year: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.labelFont)
                .foregroundStyle(.secondary)
            Text(year ?? "—")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
    }

    // MARK: - Section: Top countries

    private var topCountriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Countries")
                .font(Theme.labelFont)
                .foregroundStyle(.secondary)

            ForEach(topCountries, id: \.country) { entry in
                HStack {
                    Text(entry.country)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(entry.count)")
                        .font(Theme.labelFont)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.pin.opacity(0.85), in: Capsule())
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.ocean)

            Text("Your map is empty")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Import your photos to begin.")
                .font(Theme.labelFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview("SummaryPanel – populated") {
    let makeDate: (Int, Int, Int) -> Date = { y, m, d in
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    let places: [Place] = [
        Place(
            coordinate: Coordinate(latitude: 48.857, longitude: 2.352),
            city: "Paris", country: "France", continent: "Europe",
            visits: [
                Visit(date: makeDate(2019, 6, 10), assetIDs: ["a1", "a2"]),
                Visit(date: makeDate(2022, 9,  3), assetIDs: ["a3"])
            ],
            photoCount: 142
        ),
        Place(
            coordinate: Coordinate(latitude: 35.682, longitude: 139.691),
            city: "Tokyo", country: "Japan", continent: "Asia",
            visits: [Visit(date: makeDate(2023, 3, 18), assetIDs: ["b1"])],
            photoCount: 87
        ),
        Place(
            coordinate: Coordinate(latitude: -1.286, longitude: 36.818),
            city: "Nairobi", country: "Kenya", continent: "Africa",
            visits: [],
            photoCount: 0
        ),
        Place(
            coordinate: Coordinate(latitude: 40.713, longitude: -74.006),
            city: "New York", country: "USA", continent: "North America",
            visits: [Visit(date: makeDate(2021, 11, 5), assetIDs: ["c1", "c2"])],
            photoCount: 31
        ),
        Place(
            coordinate: Coordinate(latitude: 34.052, longitude: -118.244),
            city: "Los Angeles", country: "USA", continent: "North America",
            visits: [Visit(date: makeDate(2020, 8, 14), assetIDs: ["d1"])],
            photoCount: 54
        ),
        Place(
            coordinate: Coordinate(latitude: -33.868, longitude: 151.209),
            city: "Sydney", country: "Australia", continent: "Oceania",
            visits: [Visit(date: makeDate(2018, 2, 22), assetIDs: ["e1"])],
            photoCount: 19
        ),
    ]

    let home = Coordinate(latitude: 37.3382, longitude: -121.8863) // San Jose

    SummaryPanel(places: places, home: home)
        .frame(width: 300, height: 480)
        .padding()
        .background(Theme.ocean)
}

#Preview("SummaryPanel – empty") {
    SummaryPanel(places: [], home: nil)
        .frame(width: 300, height: 240)
        .padding()
        .background(Theme.ocean)
}
