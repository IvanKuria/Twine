import Foundation

public struct Coordinate: Equatable, Hashable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude; self.longitude = longitude
    }
}

public func haversineKilometers(_ a: Coordinate, _ b: Coordinate) -> Double {
    let r = 6371.0088
    let dLat = (b.latitude - a.latitude) * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let la1 = a.latitude * .pi / 180, la2 = b.latitude * .pi / 180
    let h = sin(dLat/2)*sin(dLat/2) + cos(la1)*cos(la2)*sin(dLon/2)*sin(dLon/2)
    return 2 * r * asin(min(1, sqrt(h)))
}
