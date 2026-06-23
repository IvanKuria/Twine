import SwiftUI
import SwiftData
import TwineKit

// MARK: - AddPlaceSheet

struct AddPlaceSheet: View {

    // MARK: - Dependencies

    let cityIndex: CityIndex

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var query: String = ""
    @State private var results: [City] = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Text("Add a Place")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search cities…", text: $query)
                    .textFieldStyle(.plain)
                    .onChange(of: query) { _, newValue in
                        results = newValue.isEmpty ? [] : cityIndex.search(newValue, limit: 20)
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Results list
            if results.isEmpty {
                Spacer()
                if query.isEmpty {
                    Text("Type a city name to search")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    Text("No results for \"\(query)\"")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Spacer()
            } else {
                List(results, id: \.name) { city in
                    Button {
                        addPlace(city)
                    } label: {
                        HStack(spacing: 4) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(city.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(city.countryCode)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Theme.pin)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 340, minHeight: 420)
    }

    // MARK: - Actions

    private func addPlace(_ city: City) {
        // Resolve country name and continent via nearest lookup
        let resolved = cityIndex.nearest(to: city.coordinate)
        let countryName = resolved?.country ?? city.countryCode
        let continent   = resolved?.continent ?? ""

        let record = PlaceRecord(
            id: UUID(),
            lat: city.coordinate.latitude,
            lon: city.coordinate.longitude,
            city: city.name,
            country: countryName,
            continent: continent,
            photoCount: 0,
            representativeAssetID: nil,
            note: nil,
            isManual: true,
            firstDate: nil,
            lastDate: nil,
            visitsJSON: "[]"
        )
        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview("AddPlaceSheet") {
    // Tiny inline CityIndex so the preview doesn't need bundled TSV data.
    let citiesTSV = """
    Paris\t48.857\t2.352\tFR\t2161000
    Tokyo\t35.682\t139.691\tJP\t13960000
    Reykjavik\t64.135\t-21.895\tIS\t123000
    Nairobi\t-1.286\t36.818\tKE\t4397073
    """
    let countriesTSV = """
    FR\tFrance\tEU
    JP\tJapan\tAS
    IS\tIceland\tEU
    KE\tKenya\tAF
    """
    let index = CityIndex(citiesTSV: citiesTSV, countriesTSV: countriesTSV)

    return AddPlaceSheet(cityIndex: index)
        .modelContainer(for: PlaceRecord.self, inMemory: true)
}
