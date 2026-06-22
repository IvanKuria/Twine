import Testing
@testable import TwineKit

@Test func equirectangularCorners() {
    #expect(Projection.project(.init(latitude: 90, longitude: -180)).y < 0.001)   // top-left
    let mid = Projection.project(.init(latitude: 0, longitude: 0))
    #expect(abs(mid.x - 0.5) < 1e-9 && abs(mid.y - 0.5) < 1e-9)
}

@Test func projectionRoundTrips() {
    let c = Coordinate(latitude: 48.85, longitude: 2.35)
    let r = Projection.unproject(Projection.project(c))
    #expect(abs(r.latitude - c.latitude) < 1e-9 && abs(r.longitude - c.longitude) < 1e-9)
}
