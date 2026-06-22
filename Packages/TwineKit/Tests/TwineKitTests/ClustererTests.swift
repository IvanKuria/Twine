import Testing
import Foundation
@testable import TwineKit

struct ClustererTests {

    @Test func nearbySamplesMergeFarOnesSplit() {
        let s = [
            PhotoSample(assetID: "a", coordinate: .init(latitude: 48.85, longitude: 2.35), date: .now),
            PhotoSample(assetID: "b", coordinate: .init(latitude: 48.86, longitude: 2.34), date: .now), // ~1km
            PhotoSample(assetID: "c", coordinate: .init(latitude: 35.68, longitude: 139.69), date: .now) // Tokyo
        ]
        let clusters = Clusterer.cluster(s, radiusKm: 40)
        #expect(clusters.count == 2)
    }

    @Test func identicalCoordinatesProduceOneCluster() {
        let coord = Coordinate(latitude: 37.7749, longitude: -122.4194)
        let samples = (0..<50).map { i in
            PhotoSample(assetID: "s\(i)", coordinate: coord, date: .now)
        }
        let clusters = Clusterer.cluster(samples, radiusKm: 40)
        #expect(clusters.count == 1)
        #expect(clusters[0].samples.count == 50)
    }
}
