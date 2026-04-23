import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum MediaLibraryPickerResult {
    case photo(UIImage)
    case video(URL)
}

struct MediaLibraryPicker: UIViewControllerRepresentable {
    let kind: HomePickerKind
    let onDismissRequested: @MainActor () -> Void
    let onResult: @MainActor (MediaLibraryPickerResult?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            kind: kind,
            onDismissRequested: onDismissRequested,
            onResult: onResult
        )
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .photoLibrary
        controller.delegate = context.coordinator
        controller.allowsEditing = false
        controller.modalPresentationStyle = .fullScreen
        controller.mediaTypes = [
            kind == .photo ? UTType.image.identifier : UTType.movie.identifier
        ]
        controller.videoQuality = .typeHigh
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let kind: HomePickerKind
        private let onDismissRequested: @MainActor () -> Void
        private let onResult: @MainActor (MediaLibraryPickerResult?) -> Void
        private var hasHandledSelection = false

        init(
            kind: HomePickerKind,
            onDismissRequested: @escaping @MainActor () -> Void,
            onResult: @escaping @MainActor (MediaLibraryPickerResult?) -> Void
        ) {
            self.kind = kind
            self.onDismissRequested = onDismissRequested
            self.onResult = onResult
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            guard !hasHandledSelection else { return }
            hasHandledSelection = true
            picker.dismiss(animated: true)
            Task { @MainActor in
                onDismissRequested()
                onResult(nil)
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard !hasHandledSelection else { return }
            hasHandledSelection = true
            picker.dismiss(animated: true)
            Task { @MainActor in
                onDismissRequested()
            }

            switch kind {
            case .photo:
                handlePhoto(info)
            case .video:
                handleVideo(info)
            }
        }

        private func handlePhoto(_ info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.originalImage] as? UIImage) ?? (info[.editedImage] as? UIImage)
            Task { @MainActor in
                onResult(image.map(MediaLibraryPickerResult.photo))
            }
        }

        private func handleVideo(_ info: [UIImagePickerController.InfoKey: Any]) {
            guard let url = info[.mediaURL] as? URL else {
                Task { @MainActor in
                    onResult(nil)
                }
                return
            }

            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("RedactFlow-\(UUID().uuidString)")
                .appendingPathExtension(url.pathExtension.isEmpty ? "mov" : url.pathExtension)

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.copyItem(at: url, to: destinationURL)

                Task { @MainActor in
                    onResult(.video(destinationURL))
                }
            } catch {
                Task { @MainActor in
                    onResult(nil)
                }
            }
        }
    }
}
