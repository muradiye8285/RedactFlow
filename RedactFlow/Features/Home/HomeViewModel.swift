import SwiftUI
import UIKit

enum HomePickerKind {
    case photo
    case video
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var isPreparingMedia = false
    @Published var hasLimitedPhotoAccess = false
    @Published var alert: EditorAlert?

    private let mediaPickerService: MediaPickerService
    private let limitedLibraryImportService: LimitedLibraryImportService
    private let photoLibraryPermissionService: PhotoLibraryPermissionService
    private let photoRedactionService: PhotoRedactionService
    private let videoRedactionService: VideoRedactionService
    private let photoLibrarySaveService: PhotoLibrarySaveService

    init(
        mediaPickerService: MediaPickerService,
        limitedLibraryImportService: LimitedLibraryImportService,
        photoLibraryPermissionService: PhotoLibraryPermissionService,
        photoRedactionService: PhotoRedactionService,
        videoRedactionService: VideoRedactionService,
        photoLibrarySaveService: PhotoLibrarySaveService
    ) {
        self.mediaPickerService = mediaPickerService
        self.limitedLibraryImportService = limitedLibraryImportService
        self.photoLibraryPermissionService = photoLibraryPermissionService
        self.photoRedactionService = photoRedactionService
        self.videoRedactionService = videoRedactionService
        self.photoLibrarySaveService = photoLibrarySaveService
        self.hasLimitedPhotoAccess = photoLibraryPermissionService.isLimitedAccess
    }

    func refreshPermissionState() {
        hasLimitedPhotoAccess = photoLibraryPermissionService.isLimitedAccess
    }

    func requestAccessAndPreparePicker(for kind: HomePickerKind) async -> Bool {
        do {
            let requestedNow = try await photoLibraryPermissionService.requestReadAccess()
            refreshPermissionState()
            if requestedNow {
                try? await Task.sleep(for: .milliseconds(450))
            }
            return true
        } catch {
            refreshPermissionState()
            alert = EditorAlert(
                title: "Photos Access Needed",
                message: error.localizedDescription,
                action: .openSettings
            )
            return false
        }
    }

    func makePhotoEditor(from image: UIImage) async -> PhotoEditorViewModel? {
        isPreparingMedia = true
        defer { isPreparingMedia = false }

        do {
            let preparedImage = try mediaPickerService.preparePhoto(image)
            return PhotoEditorViewModel(
                image: preparedImage,
                redactionService: photoRedactionService,
                saveService: photoLibrarySaveService
            )
        } catch {
            alert = EditorAlert(
                title: "Couldn’t Open Photo",
                message: error.localizedDescription
            )
            return nil
        }
    }

    func makeVideoEditor(from url: URL) async -> VideoEditorViewModel? {
        isPreparingMedia = true
        defer { isPreparingMedia = false }

        do {
            let video = try await mediaPickerService.prepareVideo(from: url)
            return VideoEditorViewModel(
                video: video,
                redactionService: videoRedactionService,
                saveService: photoLibrarySaveService
            )
        } catch {
            alert = EditorAlert(
                title: "Couldn’t Open Video",
                message: error.localizedDescription
            )
            return nil
        }
    }

    func makeLimitedLibraryBrowserViewModel(for kind: HomePickerKind) -> LimitedLibraryBrowserViewModel {
        LimitedLibraryBrowserViewModel(
            kind: kind,
            importService: limitedLibraryImportService
        )
    }
}
