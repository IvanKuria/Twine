import Foundation
import SwiftData
import TwineKit

@MainActor
@Observable
final class ImportCoordinator {

    // MARK: - Phase

    enum Phase {
        case idle, scanning, geocoding, saving, done
    }

    // MARK: - Observed state

    var phase: Phase = .idle
    var progress: Double = 0
    var noLocationCount: Int = 0

    // MARK: - Dependencies

    private let library: PhotoSampleProviding
    private let modelContext: ModelContext

    // MARK: - Init

    init(library: PhotoSampleProviding, modelContext: ModelContext) {
        self.library = library
        self.modelContext = modelContext
    }

    // MARK: - Run

    func run() async {
        // 1. Scanning
        phase = .scanning
        progress = 0.1
        let samples = await library.geotaggedSamples()
        noLocationCount = library.noLocationCount

        // 2. Geocoding
        phase = .geocoding
        progress = 0.5

        let places: [Place]
        do {
            let index = try CityIndex(
                citiesTSV: BundledData.citiesTSV(),
                countriesTSV: BundledData.countriesTSV()
            )
            let pipeline = ImportPipeline(geocoder: ReverseGeocoder(index: index))
            places = pipeline.makePlaces(from: samples)
        } catch {
            phase = .done
            progress = 1.0
            return
        }

        // 3. Saving — upsert into SwiftData
        phase = .saving
        progress = 0.9

        // Fetch all existing PlaceRecords
        let descriptor = FetchDescriptor<PlaceRecord>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []

        // Build a lookup keyed by rounded coordinate + city
        var existingByKey: [String: PlaceRecord] = [:]
        for record in existing {
            let key = upsertKey(lat: record.lat, lon: record.lon, city: record.city)
            existingByKey[key] = record
        }

        for place in places {
            let key = upsertKey(
                lat: place.coordinate.latitude,
                lon: place.coordinate.longitude,
                city: place.city
            )

            if let record = existingByKey[key] {
                // Never overwrite manual pins
                guard !record.isManual else { continue }

                // Update mutable fields; preserve user-edited note
                record.photoCount = place.photoCount
                record.representativeAssetID = place.representativeAssetID
                record.visits = place.visits
                record.firstDate = place.firstDate
                record.lastDate = place.lastDate
                record.city = place.city
                record.country = place.country
                record.continent = place.continent
                record.lat = place.coordinate.latitude
                record.lon = place.coordinate.longitude
                // note is intentionally NOT overwritten
            } else {
                // Insert new record
                let record = PlaceRecord(place)
                modelContext.insert(record)
            }
        }

        try? modelContext.save()

        // 4. Done
        phase = .done
        progress = 1.0
    }

    // MARK: - Helpers

    /// Stable identity key: lat/lon rounded to 2 decimal places + city name.
    private func upsertKey(lat: Double, lon: Double, city: String) -> String {
        let roundedLat = (lat * 100).rounded() / 100
        let roundedLon = (lon * 100).rounded() / 100
        return "\(roundedLat),\(roundedLon),\(city)"
    }
}
