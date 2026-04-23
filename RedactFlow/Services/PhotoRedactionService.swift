import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum PhotoRedactionError: LocalizedError {
    case imageUnavailable
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            return "The selected photo could not be prepared for editing."
        case .renderFailed:
            return "The redacted image could not be rendered."
        }
    }
}

final class PhotoRedactionService {
    private let context = CIContext()

    func renderPreviewImage(
        from image: UIImage,
        regions: [RedactionRegion],
        maximumDimension: CGFloat = 1500
    ) async throws -> UIImage {
        try await renderImage(from: image, regions: regions, maximumDimension: maximumDimension)
    }

    func renderFinalImage(from image: UIImage, regions: [RedactionRegion]) async throws -> UIImage {
        try await renderImage(from: image, regions: regions, maximumDimension: nil)
    }

    private func renderImage(
        from image: UIImage,
        regions: [RedactionRegion],
        maximumDimension: CGFloat?
    ) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) { [context] in
            let prepared = image.normalizedForEditing()
            guard let baseCGImage = prepared.cgImage else {
                throw PhotoRedactionError.imageUnavailable
            }

            var ciImage = CIImage(cgImage: baseCGImage)

            if let maximumDimension {
                let currentMaximum = max(ciImage.extent.width, ciImage.extent.height)
                if currentMaximum > maximumDimension {
                    let scale = maximumDimension / currentMaximum
                    ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                }
            }

            var output = ciImage
            let extent = output.extent

            for region in regions {
                output = try Self.apply(region: region, to: output, extent: extent)
            }

            guard let finalCGImage = context.createCGImage(output, from: output.extent) else {
                throw PhotoRedactionError.renderFailed
            }

            return UIImage(cgImage: finalCGImage, scale: prepared.scale, orientation: .up)
        }.value
    }

    private static func apply(region: RedactionRegion, to image: CIImage, extent: CGRect) throws -> CIImage {
        let actualRect = region.normalizedRect.denormalized(in: extent.size).integral
        let effectImage: CIImage

        switch region.style {
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = image.clampedToExtent()
            filter.radius = Float(4 + region.intensity.clamped(to: 0...1) * 28)
            effectImage = (filter.outputImage ?? image).cropped(to: extent)

        case .pixelate:
            let filter = CIFilter.pixellate()
            filter.inputImage = image.clampedToExtent()
            filter.center = CGPoint(x: actualRect.midX, y: actualRect.midY)
            filter.scale = Float(10 + region.intensity.clamped(to: 0...1) * 38)
            effectImage = (filter.outputImage ?? image).cropped(to: extent)

        case .blackBar:
            effectImage = CIImage(color: CIColor.black).cropped(to: extent)
        }

        guard let maskImage = maskImage(for: actualRect, in: extent, cornerRadius: region.cornerRadius) else {
            throw PhotoRedactionError.renderFailed
        }

        let filter = CIFilter.blendWithMask()
        filter.inputImage = effectImage
        filter.backgroundImage = image
        filter.maskImage = maskImage

        guard let output = filter.outputImage?.cropped(to: extent) else {
            throw PhotoRedactionError.renderFailed
        }

        return output
    }

    private static func maskImage(for rect: CGRect, in extent: CGRect, cornerRadius: Double) -> CIImage? {
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        rendererFormat.opaque = true

        let renderer = UIGraphicsImageRenderer(size: extent.size, format: rendererFormat)
        let mask = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: extent.size))

            UIColor.white.setFill()
            let radius = CGFloat(cornerRadius.clamped(to: 0...0.5)) * min(rect.width, rect.height)
            let roundedRect = UIBezierPath(
                roundedRect: rect.offsetBy(dx: -extent.minX, dy: -extent.minY),
                cornerRadius: radius
            )
            roundedRect.fill()
        }

        return CIImage(image: mask)
    }
}
