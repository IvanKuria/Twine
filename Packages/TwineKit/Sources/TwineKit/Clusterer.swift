import Foundation

public struct Cluster: Sendable {
    public var centroid: Coordinate
    public var samples: [PhotoSample]

    public init(centroid: Coordinate, samples: [PhotoSample]) {
        self.centroid = centroid
        self.samples = samples
    }
}

public enum Clusterer {
    /// Greedy agglomeration: deterministic sort → join first cluster within radiusKm → else new cluster.
    public static func cluster(_ samples: [PhotoSample], radiusKm: Double = 40) -> [Cluster] {
        // Deterministic order: latitude ASC, then longitude ASC, then assetID ASC for ties.
        let sorted = samples.sorted {
            if $0.coordinate.latitude != $1.coordinate.latitude {
                return $0.coordinate.latitude < $1.coordinate.latitude
            }
            if $0.coordinate.longitude != $1.coordinate.longitude {
                return $0.coordinate.longitude < $1.coordinate.longitude
            }
            return $0.assetID < $1.assetID
        }

        var clusters: [Cluster] = []

        for sample in sorted {
            if let idx = clusters.firstIndex(where: { haversineKilometers($0.centroid, sample.coordinate) <= radiusKm }) {
                clusters[idx].samples.append(sample)
                // Update centroid as running mean.
                let n = Double(clusters[idx].samples.count)
                let prev = clusters[idx].centroid
                clusters[idx].centroid = Coordinate(
                    latitude:  prev.latitude  + (sample.coordinate.latitude  - prev.latitude)  / n,
                    longitude: prev.longitude + (sample.coordinate.longitude - prev.longitude) / n
                )
            } else {
                clusters.append(Cluster(centroid: sample.coordinate, samples: [sample]))
            }
        }

        return clusters
    }
}
