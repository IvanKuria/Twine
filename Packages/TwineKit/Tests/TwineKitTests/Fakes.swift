import Foundation
@testable import TwineKit

final class FakePhotoSampleProvider: PhotoSampleProviding, @unchecked Sendable {
    var samples: [PhotoSample]
    var noLocationCount: Int

    init(samples: [PhotoSample] = [], noLocationCount: Int = 0) {
        self.samples = samples
        self.noLocationCount = noLocationCount
    }

    func geotaggedSamples() async -> [PhotoSample] { samples }
}

// MARK: - Fixture data

extension FakePhotoSampleProvider {
    /// Paris x3 over two days, Tokyo x1, SF x2. Reusable across later task tests.
    static let parisTokyoSF: [PhotoSample] = {
        let paris = Coordinate(latitude: 48.8566, longitude: 2.3522)
        let tokyo = Coordinate(latitude: 35.6762, longitude: 139.6503)
        let sf    = Coordinate(latitude: 37.7749, longitude: -122.4194)

        let day0 = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14
        let day1 = day0 + 86_400                              // 2023-11-15

        return [
            PhotoSample(assetID: "paris-1", coordinate: paris, date: day0),
            PhotoSample(assetID: "paris-2", coordinate: paris, date: day0 + 3_600),
            PhotoSample(assetID: "paris-3", coordinate: paris, date: day1),
            PhotoSample(assetID: "tokyo-1", coordinate: tokyo, date: day1 + 7_200),
            PhotoSample(assetID: "sf-1",    coordinate: sf,    date: day1 + 14_400),
            PhotoSample(assetID: "sf-2",    coordinate: sf,    date: day1 + 18_000),
        ]
    }()
}
