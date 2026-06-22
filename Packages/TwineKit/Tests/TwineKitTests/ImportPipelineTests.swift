import Testing
import Foundation
@testable import TwineKit

@Suite("ImportPipeline")
struct ImportPipelineTests {

    private func makeGeocoder() -> ReverseGeocoder {
        let cities    = "Paris\t48.8566\t2.3522\tFR\t2148000\nTokyo\t35.6895\t139.6917\tJP\t8336599\n"
        let countries = "FR\tFrance\tEU\nJP\tJapan\tAS\n"
        return ReverseGeocoder(index: CityIndex(citiesTSV: cities, countriesTSV: countries))
    }

    @Test func buildsPlacesWithMergedVisits() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86_400 * 5)
        let samples = [
            PhotoSample(assetID: "p1", coordinate: .init(latitude: 48.85, longitude: 2.35), date: day1),
            PhotoSample(assetID: "p2", coordinate: .init(latitude: 48.86, longitude: 2.34), date: day1),
            PhotoSample(assetID: "p3", coordinate: .init(latitude: 48.85, longitude: 2.35), date: day2),
            PhotoSample(assetID: "t1", coordinate: .init(latitude: 35.68, longitude: 139.69), date: day1),
        ]
        let pipe = ImportPipeline(geocoder: makeGeocoder())
        let places = pipe.makePlaces(from: samples)
        let paris = places.first { $0.city == "Paris" }!
        #expect(places.count == 2)
        #expect(paris.photoCount == 3)
        #expect(paris.visits.count == 2)        // two distinct UTC days
    }

    @Test func emptyInputProducesNoPlaces() {
        let pipe = ImportPipeline(geocoder: makeGeocoder())
        let places = pipe.makePlaces(from: [])
        #expect(places.isEmpty)
    }

    @Test func sortsByPhotoCountDescending() {
        // Paris gets 3 photos, Tokyo gets 1 — Paris should be first after sorting.
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86_400 * 5)
        let samples = [
            PhotoSample(assetID: "p1", coordinate: .init(latitude: 48.85, longitude: 2.35), date: day1),
            PhotoSample(assetID: "p2", coordinate: .init(latitude: 48.86, longitude: 2.34), date: day1),
            PhotoSample(assetID: "p3", coordinate: .init(latitude: 48.85, longitude: 2.35), date: day2),
            PhotoSample(assetID: "t1", coordinate: .init(latitude: 35.68, longitude: 139.69), date: day1),
        ]
        let pipe = ImportPipeline(geocoder: makeGeocoder())
        let places = pipe.makePlaces(from: samples)
        #expect(places.first?.city == "Paris")
    }
}
