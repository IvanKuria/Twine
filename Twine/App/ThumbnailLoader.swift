import Photos
import AppKit

// MARK: - ThumbnailLoader

/// Resolves PHAsset local identifiers to NSImage thumbnails.
/// Missing or deleted assets return nil — callers show a placeholder.
@MainActor
final class ThumbnailLoader {

    // Shared caching manager; reused across requests for efficiency.
    private let manager = PHCachingImageManager()

    // MARK: - Public API

    /// Fetches a thumbnail for the given asset identifier at the requested size.
    /// Returns nil if the asset doesn't exist or the image can't be fetched.
    func image(for assetID: String, target: CGSize) async -> NSImage? {
        // Fetch the PHAsset synchronously (lightweight metadata-only fetch).
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        return await withCheckedContinuation { continuation in
            var didResume = false
            manager.requestImage(
                for: asset,
                targetSize: target,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                // Belt-and-suspenders guard: never resume the continuation twice.
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
        }
    }
}
