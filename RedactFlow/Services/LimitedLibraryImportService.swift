import Photos
import UIKit

enum LimitedLibraryImportError: LocalizedError {
    case unavailableImage
    case unavailableVideo
    case localCopyUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailableImage:
            return "This photo could not be loaded from your limited library selection."
        case .unavailableVideo:
            return "This video could not be loaded from your limited library selection."
        case .localCopyUnavailable:
            return "This item is not currently stored locally on your iPhone. Open Photos first if you need iCloud to download it."
        }
    }
}

struct LimitedLibraryAsset: Identifiable {
    let asset: PHAsset

    var id: String { asset.localIdentifier }
    var isVideo: Bool { asset.mediaType == .video }

    var durationText: String? {
        guard isVideo else { return nil }
        let totalSeconds = Int(asset.duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }
}

final class LimitedLibraryImportService {
    private let imageManager = PHCachingImageManager()

    func fetchAssets(mediaType: PHAssetMediaType) -> [LimitedLibraryAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var assets: [LimitedLibraryAsset] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            assets.append(LimitedLibraryAsset(asset: asset))
        }

        return assets
    }

    func loadThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false

            var hasResumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false

                if cancelled {
                    hasResumed = true
                    continuation.resume(returning: nil)
                    return
                }

                if !isDegraded || image == nil {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func loadPhoto(from asset: PHAsset) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.version = .current
            options.isNetworkAccessAllowed = false

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let inCloud = info?[PHImageResultIsInCloudKey] as? Bool, inCloud {
                    continuation.resume(throwing: LimitedLibraryImportError.localCopyUnavailable)
                    return
                }

                guard let data, let image = UIImage(data: data) else {
                    continuation.resume(throwing: LimitedLibraryImportError.unavailableImage)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    func loadVideoURL(from asset: PHAsset) async throws -> URL {
        guard let resource = preferredVideoResource(for: asset) else {
            throw LimitedLibraryImportError.unavailableVideo
        }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RedactFlow-\(UUID().uuidString)")
            .appendingPathExtension(resource.originalFilename.pathExtensionIfPresent ?? "mov")

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: destinationURL, options: options) { error in
                if let error = error as NSError? {
                    if error.domain == PHPhotosErrorDomain {
                        continuation.resume(throwing: LimitedLibraryImportError.localCopyUnavailable)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                continuation.resume(returning: ())
            }
        }

        return destinationURL
    }

    private func preferredVideoResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        return resources.first(where: { $0.type == .fullSizeVideo })
            ?? resources.first(where: { $0.type == .video })
            ?? resources.first(where: { $0.type == .pairedVideo })
            ?? resources.first
    }
}

private extension String {
    var pathExtensionIfPresent: String? {
        let ext = (self as NSString).pathExtension
        return ext.isEmpty ? nil : ext
    }
}
