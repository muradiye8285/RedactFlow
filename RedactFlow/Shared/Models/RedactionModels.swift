import CoreGraphics
import Foundation

struct PickedVideo {
    let url: URL
    let displaySize: CGSize
    let duration: Double
}

enum RedactionStyle: String, CaseIterable, Codable, Identifiable {
    case blur
    case pixelate
    case blackBar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blur:
            return "Blur"
        case .pixelate:
            return "Pixelate"
        case .blackBar:
            return "Black Bar"
        }
    }

    var systemImage: String {
        switch self {
        case .blur:
            return "drop"
        case .pixelate:
            return "square.grid.3x3.fill"
        case .blackBar:
            return "rectangle.fill"
        }
    }

    var supportsIntensity: Bool {
        self != .blackBar
    }
}

struct RedactionRegion: Identifiable, Equatable, Codable {
    let id: UUID
    var normalizedRect: CGRect
    var style: RedactionStyle
    var intensity: Double
    var cornerRadius: Double

    init(
        id: UUID = UUID(),
        normalizedRect: CGRect,
        style: RedactionStyle = .blur,
        intensity: Double = 0.55,
        cornerRadius: Double = 0.08
    ) {
        self.id = id
        self.normalizedRect = normalizedRect
        self.style = style
        self.intensity = intensity
        self.cornerRadius = cornerRadius
    }
}

struct RedactionEditorSnapshot: Equatable {
    var regions: [RedactionRegion]
    var selectedRegionID: UUID?
}

enum EditorAlertAction: Equatable {
    case dismiss
    case openSettings
    case openPhotos
}

struct EditorAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let action: EditorAlertAction

    init(
        title: String,
        message: String,
        action: EditorAlertAction = .dismiss
    ) {
        self.title = title
        self.message = message
        self.action = action
    }
}
