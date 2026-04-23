import AVFoundation
import UIKit

enum MediaPickerError: LocalizedError {
    case unreadableImage
    case unreadableVideo
    case unsupportedMedia

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "This photo could not be opened."
        case .unreadableVideo:
            return "This video could not be opened."
        case .unsupportedMedia:
            return "This media type is not supported."
        }
    }
}

final class MediaPickerService {
    func preparePhoto(_ image: UIImage) throws -> UIImage {
        return image.normalizedForEditing()
    }

    func prepareVideo(from url: URL) async throws -> PickedVideo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let track = tracks.first else {
            throw MediaPickerError.unsupportedMedia
        }

        let displaySize = try await track.presentationSize()

        return PickedVideo(
            url: url,
            displaySize: displaySize,
            duration: duration.isFinite ? duration : 0
        )
    }
}
