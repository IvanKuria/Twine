import SwiftUI
import SwiftData
import TwineKit

// MARK: - ContentView

struct ContentView: View {

    // MARK: - SwiftData

    @Environment(\.modelContext) private var modelContext
    @Query private var placeRecords: [PlaceRecord]
    @Query private var homeRecords: [HomeRecord]

    // MARK: - State

    @State private var selectedPlaceID: UUID? = nil
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showAddPlace = false
    @State private var showSetHome = false

    /// Built once off-main via .task.
    @State private var cityIndex: CityIndex? = nil

    // MARK: - Derived

    private var places: [Place] { placeRecords.map(\.place) }

    private var home: Coordinate? { homeRecords.first?.coordinate }

    private var selectedRecord: PlaceRecord? {
        guard let id = selectedPlaceID else { return nil }
        return placeRecords.first { $0.id == id }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            Sidebar(places: places, selectedPlaceID: $selectedPlaceID)
        } content: {
            BoardView(
                places: places,
                home: home,
                selectedPlaceID: $selectedPlaceID,
                scale: $scale,
                offset: $offset
            )
            .frame(minWidth: 480, minHeight: 320)
        } detail: {
            if let record = selectedRecord {
                PinDetail(record: record)
            } else {
                SummaryPanel(places: places, home: home)
                    .padding(12)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ExportView(places: places, home: home)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSetHome = true
                } label: {
                    Label("Set Home", systemImage: "house")
                }
                .help("Set your home city for thread anchoring")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddPlace = true
                } label: {
                    Label("Add Place", systemImage: "plus")
                }
                .disabled(cityIndex == nil)
                .help(cityIndex == nil ? "Loading city index…" : "Add a place manually")
            }
        }
        // Build CityIndex once off-main.
        .task {
            guard cityIndex == nil else { return }
            cityIndex = await Task.detached(priority: .userInitiated) {
                guard let cities = try? BundledData.citiesTSV(),
                      let countries = try? BundledData.countriesTSV()
                else { return nil }
                return CityIndex(citiesTSV: cities, countriesTSV: countries)
            }.value
        }
        // Add Place sheet.
        .sheet(isPresented: $showAddPlace) {
            if let idx = cityIndex {
                AddPlaceSheet(cityIndex: idx)
            }
        }
        // Set Home sheet.
        .sheet(isPresented: $showSetHome) {
            SetHomeSheet(homeRecords: homeRecords, cityIndex: cityIndex)
        }
    }
}

// MARK: - City composite key

private extension City {
    /// Stable composite identifier used as List row id to avoid collisions on duplicate city names.
    var compositeKey: String { "\(name)-\(countryCode)-\(coordinate.latitude)-\(coordinate.longitude)" }
}

// MARK: - SetHomeSheet

private struct SetHomeSheet: View {

    let homeRecords: [HomeRecord]
    let cityIndex: CityIndex?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [City] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Set Home")
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
                        guard let idx = cityIndex else { return }
                        results = newValue.isEmpty ? [] : idx.search(newValue, limit: 20)
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

            // Results
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
                List(results, id: \.compositeKey) { city in
                    Button {
                        upsertHome(city)
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
                            Image(systemName: "house")
                                .foregroundStyle(Theme.home)
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

    private func upsertHome(_ city: City) {
        // Delete all existing home records (enforce single home).
        for record in homeRecords {
            modelContext.delete(record)
        }
        let label = city.name
        let record = HomeRecord(
            lat: city.coordinate.latitude,
            lon: city.coordinate.longitude,
            label: label
        )
        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}
