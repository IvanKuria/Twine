import Foundation

public struct PhotoSample: Sendable, Equatable {
    public let assetID: String
    public let coordinate: Coordinate
    public let date: Date

    public init(assetID: String, coordinate: Coordinate, date: Date) {
        self.assetID = assetID
        self.coordinate = coordinate
        self.date = date
    }
}

public struct Visit: Sendable, Equatable {
    public let date: Date
    public let assetIDs: [String]

    public init(date: Date, assetIDs: [String]) {
        self.date = date
        self.assetIDs = assetIDs
    }
}

public struct Place: Sendable, Identifiable, Equatable {
    public let id: UUID
    public var coordinate: Coordinate
    public var city: String
    public var country: String
    public var continent: String
    public var visits: [Visit]
    public var photoCount: Int
    public var representativeAssetID: String?
    public var note: String?
    public var isManual: Bool

    public init(
        id: UUID = UUID(),
        coordinate: Coordinate,
        city: String,
        country: String,
        continent: String,
        visits: [Visit] = [],
        photoCount: Int = 0,
        representativeAssetID: String? = nil,
        note: String? = nil,
        isManual: Bool = false
    ) {
        self.id = id
        self.coordinate = coordinate
        self.city = city
        self.country = country
        self.continent = continent
        self.visits = visits
        self.photoCount = photoCount
        self.representativeAssetID = representativeAssetID
        self.note = note
        self.isManual = isManual
    }

    public var firstDate: Date? { visits.map(\.date).min() }
    public var lastDate: Date? { visits.map(\.date).max() }
}
