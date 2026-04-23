import Photos
import SwiftUI

@MainActor
final class LimitedLibraryBrowserViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    let kind: HomePickerKind

    @Published private(set) var assets: [LimitedLibraryAsset] = []
    @Published var isLoadingAssets = false
    @Published var isImportingSelection = false
    @Published var alert: EditorAlert?

    private let importService: LimitedLibraryImportService

    init(
        kind: HomePickerKind,
        importService: LimitedLibraryImportService
    ) {
        self.kind = kind
        self.importService = importService
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    var title: String {
        switch kind {
        case .photo:
            return "Choose Photo"
        case .video:
            return "Choose Video"
        }
    }

    var subtitle: String {
        switch kind {
        case .photo:
            return "Only photos you've allowed to RedactFlow appear here."
        case .video:
            return "Only videos you've allowed to RedactFlow appear here."
        }
    }

    var emptyTitle: String {
        switch kind {
        case .photo:
            return "No Photos Available"
        case .video:
            return "No Videos Available"
        }
    }

    var emptyMessage: String {
        switch kind {
        case .photo:
            return "Update your limited Photos selection or switch to Full Access to import a photo."
        case .video:
            return "Update your limited Photos selection or switch to Full Access to import a video."
        }
    }

    func loadAssets() {
        isLoadingAssets = true
        assets = importService.fetchAssets(mediaType: mediaType)
        isLoadingAssets = false
    }

    func importAsset(_ asset: LimitedLibraryAsset) async -> MediaLibraryPickerResult? {
        isImportingSelection = true
        defer { isImportingSelection = false }

        do {
            switch kind {
            case .photo:
                let image = try await importService.loadPhoto(from: asset.asset)
                return .photo(image)
            case .video:
                let url = try await importService.loadVideoURL(from: asset.asset)
                return .video(url)
            }
        } catch {
            alert = EditorAlert(
                title: kind == .photo ? "Couldn’t Open Photo" : "Couldn’t Open Video",
                message: error.localizedDescription
            )
            return nil
        }
    }

    func thumbnail(for asset: LimitedLibraryAsset, targetSize: CGSize) async -> UIImage? {
        await importService.loadThumbnail(for: asset.asset, targetSize: targetSize)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            self?.loadAssets()
        }
    }

    private var mediaType: PHAssetMediaType {
        switch kind {
        case .photo:
            return .image
        case .video:
            return .video
        }
    }
}
