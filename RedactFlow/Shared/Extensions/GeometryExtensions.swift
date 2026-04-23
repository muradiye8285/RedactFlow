import AVFoundation
import CoreGraphics
import UIKit

extension CGSize {
    func aspectFit(in boundingSize: CGSize) -> CGSize {
        guard width > 0, height > 0, boundingSize.width > 0, boundingSize.height > 0 else {
            return .zero
        }

        let scale = min(boundingSize.width / width, boundingSize.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }
}

extension CGRect {
    func denormalized(in size: CGSize) -> CGRect {
        CGRect(
            x: minX * size.width,
            y: minY * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }

    func normalized(in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGRect(
            x: minX / size.width,
            y: minY / size.height,
            width: width / size.width,
            height: height / size.height
        )
    }

    func clampedToUnitSpace(minSize: CGFloat = 0.08) -> CGRect {
        let safeWidth = max(minSize, min(width, 1))
        let safeHeight = max(minSize, min(height, 1))
        let safeX = min(max(0, minX), 1 - safeWidth)
        let safeY = min(max(0, minY), 1 - safeHeight)
        return CGRect(x: safeX, y: safeY, width: safeWidth, height: safeHeight)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension UIImage {
    func normalizedForEditing() -> UIImage {
        guard imageOrientation != .up else { return self }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension AVAssetTrack {
    func presentationSize() async throws -> CGSize {
        let naturalSize = try await load(.naturalSize)
        let preferredTransform = try await load(.preferredTransform)
        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)

        return CGSize(
            width: abs(transformedRect.width),
            height: abs(transformedRect.height)
        )
    }
}
