import Foundation

public struct UnitPoint2D: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum Projection {
    public static func project(_ c: Coordinate) -> UnitPoint2D {
        UnitPoint2D(x: (c.longitude + 180) / 360, y: (90 - c.latitude) / 180)
    }

    public static func unproject(_ p: UnitPoint2D) -> Coordinate {
        Coordinate(latitude: 90 - p.y * 180, longitude: p.x * 360 - 180)
    }
}
