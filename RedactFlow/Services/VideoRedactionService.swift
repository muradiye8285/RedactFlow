@preconcurrency import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum VideoRedactionError: LocalizedError {
    case exportSessionUnavailable
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .exportSessionUnavailable:
            return "This video could not be prepared for export."
        case .exportFailed:
            return "The redacted video export failed."
        }
    }
}

final class VideoRedactionService {
    func exportVideo(
        asset: AVAsset,
        regions: [RedactionRegion],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let preparedRegions = try await prepareRegions(for: asset, regions: regions)
        let videoComposition = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { [preparedRegions] request in
            let source = request.sourceImage.clampedToExtent()
            let extent = request.sourceImage.extent
            var output = source

            for region in preparedRegions {
                output = Self.applyPreparedRegion(region, to: output, extent: extent)
            }

            request.finish(with: output.cropped(to: extent), context: nil)
        })

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoRedactionError.exportSessionUnavailable
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RedactFlow-\(UUID().uuidString)")
            .appendingPathExtension("mov")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        exportSession.videoComposition = videoComposition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = false
        let sessionBox = ExportSessionBox(exportSession)

        return try await withThrowingTaskGroup(of: URL.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    sessionBox.session.exportAsynchronously {
                        switch sessionBox.session.status {
                        case .completed:
                            continuation.resume(returning: outputURL)
                        case .failed, .cancelled:
                            continuation.resume(throwing: sessionBox.session.error ?? VideoRedactionError.exportFailed)
                        default:
                            continuation.resume(throwing: VideoRedactionError.exportFailed)
                        }
                    }
                }
            }

            group.addTask {
                while !Task.isCancelled {
                    progressHandler(Double(sessionBox.session.progress))
                    try await Task.sleep(for: .milliseconds(120))
                }
                return outputURL
            }

            guard let result = try await group.next() else {
                throw VideoRedactionError.exportFailed
            }
            group.cancelAll()
            progressHandler(1)
            return result
        }
    }

    private func prepareRegions(for asset: AVAsset, regions: [RedactionRegion]) async throws -> [PreparedVideoRegion] {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { return [] }
        let renderSize = try await track.presentationSize()

        return regions.map { region in
            let actualRect = region.normalizedRect.denormalized(in: renderSize).integral
            let mask = Self.makeMaskImage(for: actualRect, renderSize: renderSize, cornerRadius: region.cornerRadius)
            return PreparedVideoRegion(
                region: region,
                rect: actualRect,
                maskImage: mask
            )
        }
    }

    private static func applyPreparedRegion(_ region: PreparedVideoRegion, to image: CIImage, extent: CGRect) -> CIImage {
        let effectImage: CIImage

        switch region.region.style {
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = image.clampedToExtent()
            filter.radius = Float(4 + region.region.intensity.clamped(to: 0...1) * 28)
            effectImage = (filter.outputImage ?? image).cropped(to: extent)

        case .pixelate:
            let filter = CIFilter.pixellate()
            filter.inputImage = image.clampedToExtent()
            filter.center = CGPoint(x: region.rect.midX, y: region.rect.midY)
            filter.scale = Float(10 + region.region.intensity.clamped(to: 0...1) * 38)
            effectImage = (filter.outputImage ?? image).cropped(to: extent)

        case .blackBar:
            effectImage = CIImage(color: CIColor.black).cropped(to: extent)
        }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = effectImage
        blend.backgroundImage = image
        blend.maskImage = region.maskImage
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    private static func makeMaskImage(for rect: CGRect, renderSize: CGSize, cornerRadius: Double) -> CIImage {
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        rendererFormat.opaque = true

        let renderer = UIGraphicsImageRenderer(size: renderSize, format: rendererFormat)
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            UIColor.white.setFill()
            let radius = CGFloat(cornerRadius.clamped(to: 0...0.5)) * min(rect.width, rect.height)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            path.fill()
        }

        return CIImage(image: image) ?? CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: renderSize))
    }
}

private struct PreparedVideoRegion {
    let region: RedactionRegion
    let rect: CGRect
    let maskImage: CIImage
}

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
