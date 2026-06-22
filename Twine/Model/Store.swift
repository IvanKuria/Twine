import Foundation
import SwiftData
import TwineKit

// MARK: - PlaceRecord

@Model
final class PlaceRecord {
    var id: UUID
    var lat: Double
    var lon: Double
    var city: String
    var country: String
    var continent: String
    var photoCount: Int
    var representativeAssetID: String?
    var note: String?
    var isManual: Bool
    var firstDate: Date?
    var lastDate: Date?
    /// JSON-encoded `[TwineKit.Visit]`
    var visitsJSON: String

    init(
        id: UUID,
        lat: Double,
        lon: Double,
        city: String,
        country: String,
        continent: String,
        photoCount: Int,
        representativeAssetID: String?,
        note: String?,
        isManual: Bool,
        firstDate: Date?,
        lastDate: Date?,
        visitsJSON: String
    ) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.city = city
        self.country = country
        self.continent = continent
        self.photoCount = photoCount
        self.representativeAssetID = representativeAssetID
        self.note = note
        self.isManual = isManual
        self.firstDate = firstDate
        self.lastDate = lastDate
        self.visitsJSON = visitsJSON
    }

    // MARK: Computed visits

    var visits: [Visit] {
        get {
            guard let data = visitsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([VisitDTO].self, from: data)
            else { return [] }
            return decoded.map { Visit(date: $0.date, assetIDs: $0.assetIDs) }
        }
        set {
            let dtos = newValue.map { VisitDTO(date: $0.date, assetIDs: $0.assetIDs) }
            if let data = try? JSONEncoder().encode(dtos),
               let str = String(data: data, encoding: .utf8) {
                visitsJSON = str
            }
        }
    }
}

// MARK: - PlaceRecord mappers

extension PlaceRecord {
    convenience init(_ place: Place) {
        let dtos = place.visits.map { VisitDTO(date: $0.date, assetIDs: $0.assetIDs) }
        let json: String
        if let data = try? JSONEncoder().encode(dtos),
           let str = String(data: data, encoding: .utf8) {
            json = str
        } else {
            json = "[]"
        }
        self.init(
            id: place.id,
            lat: place.coordinate.latitude,
            lon: place.coordinate.longitude,
            city: place.city,
            country: place.country,
            continent: place.continent,
            photoCount: place.photoCount,
            representativeAssetID: place.representativeAssetID,
            note: place.note,
            isManual: place.isManual,
            firstDate: place.firstDate,
            lastDate: place.lastDate,
            visitsJSON: json
        )
    }

    var place: Place {
        Place(
            id: id,
            coordinate: Coordinate(latitude: lat, longitude: lon),
            city: city,
            country: country,
            continent: continent,
            visits: visits,
            photoCount: photoCount,
            representativeAssetID: representativeAssetID,
            note: note,
            isManual: isManual
        )
    }
}

// MARK: - HomeRecord

@Model
final class HomeRecord {
    var lat: Double
    var lon: Double
    var label: String

    init(lat: Double, lon: Double, label: String) {
        self.lat = lat
        self.lon = lon
        self.label = label
    }

    var coordinate: Coordinate {
        Coordinate(latitude: lat, longitude: lon)
    }
}

// MARK: - Store

enum Store {
    @MainActor
    static func container() -> ModelContainer {
        do {
            return try ModelContainer(for: PlaceRecord.self, HomeRecord.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }
}

// MARK: - VisitDTO (private JSON bridge)

private struct VisitDTO: Codable {
    var date: Date
    var assetIDs: [String]
}
