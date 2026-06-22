import Testing
@testable import TwineKit

@Test func haversineKnownDistance() {
    let sf = Coordinate(latitude: 37.7749, longitude: -122.4194)
    let ny = Coordinate(latitude: 40.7128, longitude: -74.0060)
    let km = haversineKilometers(sf, ny)
    #expect(abs(km - 4129) < 30)   // ~4129 km
}
