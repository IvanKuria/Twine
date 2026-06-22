import Photos
import CoreLocation
import TwineKit

public enum PhotoAuth {
    case notDetermined, denied, limited, full
}

private func mapStatus(_ status: PHAuthorizationStatus) -> PhotoAuth {
    switch status {
    case .notDetermined:            return .notDetermined
    case .denied, .restricted:      return .denied
    case .limited:                  return .limited
    case .authorized:               return .full
    @unknown default:               return .denied
    }
}

final class PhotoLibrary: PhotoSampleProviding, @unchecked Sendable {

    // Protected by nonisolated(unsafe) — written only from the scan helper
    // which runs synchronously on a background thread before returning to async.
    private nonisolated(unsafe) var _noLocationCount: Int = 0

    var noLocationCount: Int { _noLocationCount }

    func authorization() -> PhotoAuth {
        mapStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> PhotoAuth {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return mapStatus(status)
    }

    func geotaggedSamples() async -> [PhotoSample] {
        // Run the synchronous PHAsset enumeration on a background thread.
        let (samples, noLoc) = await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.includeHiddenAssets = false
            let result = PHAsset.fetchAssets(with: .image, options: options)

            var samples: [PhotoSample] = []
            var noLoc = 0

            result.enumerateObjects { asset, _, _ in
                guard let location = asset.location else {
                    noLoc += 1
                    return
                }
                let coord = Coordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                let date = asset.creationDate ?? Date(timeIntervalSince1970: 0)
                samples.append(PhotoSample(
                    assetID: asset.localIdentifier,
                    coordinate: coord,
                    date: date
                ))
            }

            return (samples, noLoc)
        }.value

        _noLocationCount = noLoc
        return samples
    }
}
