import Photos

enum PhotoLibraryPermissionError: LocalizedError {
    case denied
    case restricted

    var errorDescription: String? {
        switch self {
        case .denied:
            return "RedactFlow needs Photos access to let you choose images and videos on this device. You can allow access in Settings."
        case .restricted:
            return "Photos access is restricted on this device."
        }
    }
}

final class PhotoLibraryPermissionService {
    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var isLimitedAccess: Bool {
        authorizationStatus == .limited
    }

    func requestReadAccess() async throws -> Bool {
        let currentStatus = authorizationStatus
        let resolvedStatus: PHAuthorizationStatus
        let requestedNow: Bool

        switch currentStatus {
        case .authorized, .limited:
            resolvedStatus = currentStatus
            requestedNow = false
        case .notDetermined:
            resolvedStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            requestedNow = true
        case .denied:
            throw PhotoLibraryPermissionError.denied
        case .restricted:
            throw PhotoLibraryPermissionError.restricted
        @unknown default:
            throw PhotoLibraryPermissionError.denied
        }

        guard resolvedStatus == .authorized || resolvedStatus == .limited else {
            if resolvedStatus == .restricted {
                throw PhotoLibraryPermissionError.restricted
            }
            throw PhotoLibraryPermissionError.denied
        }

        return requestedNow
    }
}
