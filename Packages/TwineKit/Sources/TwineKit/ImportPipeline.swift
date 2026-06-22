import Foundation

public struct ImportPipeline: Sendable {

    private let geocoder: ReverseGeocoder
    private let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    public init(geocoder: ReverseGeocoder) {
        self.geocoder = geocoder
    }

    /// Clusters `samples` into geographic places, groups each cluster's samples
    /// into `Visit`s by calendar day (UTC), and returns places sorted by
    /// `photoCount` descending (stable).
    public func makePlaces(from samples: [PhotoSample]) -> [Place] {
        guard !samples.isEmpty else { return [] }

        let clusters = Clusterer.cluster(samples)

        var places: [Place] = clusters.map { cluster in
            let (city, country, continent) = geocoder.resolve(cluster.centroid)

            // Group samples into visits by UTC day.
            let visits = visitsByUTCDay(cluster.samples)

            // representativeAssetID = newest sample's assetID
            let newest = cluster.samples.max(by: { $0.date < $1.date })

            return Place(
                coordinate: cluster.centroid,
                city: city,
                country: country,
                continent: continent,
                visits: visits,
                photoCount: cluster.samples.count,
                representativeAssetID: newest?.assetID,
                note: nil,
                isManual: false
            )
        }

        // Stable sort: photoCount descending. Swift's sort is stable in 5.5+.
        places.sort { $0.photoCount > $1.photoCount }
        return places
    }

    // MARK: - Private

    private func visitsByUTCDay(_ samples: [PhotoSample]) -> [Visit] {
        // Bucket samples by their UTC calendar day.
        var buckets: [DateComponents: [PhotoSample]] = [:]
        for sample in samples {
            let key = utcCalendar.dateComponents([.year, .month, .day], from: sample.date)
            buckets[key, default: []].append(sample)
        }

        // Build a Visit per bucket; date = the earliest sample in that day.
        return buckets.map { (key, daySamples) in
            let dayStart = utcCalendar.date(from: key) ?? daySamples.min(by: { $0.date < $1.date })!.date
            let assetIDs = daySamples.map(\.assetID).sorted()
            return Visit(date: dayStart, assetIDs: assetIDs)
        }
        .sorted { $0.date < $1.date }   // chronological order within place
    }
}
