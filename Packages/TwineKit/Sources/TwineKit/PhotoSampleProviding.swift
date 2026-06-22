import Foundation

public protocol PhotoSampleProviding: Sendable {
    func geotaggedSamples() async -> [PhotoSample]
    var noLocationCount: Int { get }
}
