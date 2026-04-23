import SwiftUI

@MainActor
final class PhotoEditorViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let originalImage: UIImage

    @Published private(set) var previewImage: UIImage
    @Published private(set) var regions: [RedactionRegion] = []
    @Published private(set) var selectedRegionID: UUID?
    @Published var isExporting = false
    @Published var alert: EditorAlert?

    private let redactionService: PhotoRedactionService
    private let saveService: PhotoLibrarySaveService
    private let historyController = RedactionHistoryController()

    private var gestureBaselineRect: CGRect?
    private var gestureRegionID: UUID?
    private var previewTask: Task<Void, Never>?

    init(
        image: UIImage,
        redactionService: PhotoRedactionService,
        saveService: PhotoLibrarySaveService
    ) {
        let normalizedImage = image.normalizedForEditing()
        self.originalImage = normalizedImage
        self.previewImage = normalizedImage
        self.redactionService = redactionService
        self.saveService = saveService
    }

    var canvasSize: CGSize {
        originalImage.size
    }

    var selectedRegion: RedactionRegion? {
        guard let selectedRegionID else { return nil }
        return regions.first(where: { $0.id == selectedRegionID })
    }

    var canUndo: Bool { historyController.canUndo }
    var canRedo: Bool { historyController.canRedo }
    var hasRegions: Bool { !regions.isEmpty }

    func addRegion() {
        captureHistory()

        let offset = min(Double(regions.count) * 0.04, 0.18)
        let region = RedactionRegion(
            normalizedRect: CGRect(x: 0.18 + offset, y: 0.18 + offset, width: 0.34, height: 0.18)
                .clampedToUnitSpace(minSize: 0.12),
            style: .blur,
            intensity: 0.55,
            cornerRadius: 0.08
        )

        regions.append(region)
        selectedRegionID = region.id
        refreshPreview()
    }

    func selectRegion(_ id: UUID) {
        selectedRegionID = id
    }

    func updateSelectedStyle(_ style: RedactionStyle) {
        guard var region = selectedRegion else { return }
        captureHistory()
        region.style = style
        if style == .blackBar {
            region.intensity = 1
        }
        replace(region)
        refreshPreview()
    }

    func updateSelectedIntensity(_ intensity: Double) {
        guard var region = selectedRegion else { return }
        captureHistory()
        region.intensity = intensity.clamped(to: 0...1)
        replace(region)
        refreshPreview()
    }

    func updateSelectedCornerRadius(_ radius: Double) {
        guard var region = selectedRegion else { return }
        captureHistory()
        region.cornerRadius = radius.clamped(to: 0...0.5)
        replace(region)
        refreshPreview()
    }

    func deleteSelectedRegion() {
        guard let selectedRegionID else { return }
        captureHistory()
        regions.removeAll(where: { $0.id == selectedRegionID })
        self.selectedRegionID = regions.last?.id
        refreshPreview()
    }

    func resetAll() {
        guard !regions.isEmpty else { return }
        captureHistory()
        regions.removeAll()
        selectedRegionID = nil
        refreshPreview()
    }

    func undo() {
        guard let snapshot = historyController.undo(from: snapshot) else { return }
        apply(snapshot: snapshot)
    }

    func redo() {
        guard let snapshot = historyController.redo(from: snapshot) else { return }
        apply(snapshot: snapshot)
    }

    func beginMove(for regionID: UUID) {
        startGesture(for: regionID)
    }

    func move(regionID: UUID, translation: CGSize, canvasSize: CGSize) {
        guard gestureRegionID == regionID, let baseline = gestureBaselineRect else { return }
        let dx = translation.width / max(canvasSize.width, 1)
        let dy = translation.height / max(canvasSize.height, 1)

        var updatedRect = baseline.offsetBy(dx: dx, dy: dy)
        updatedRect.origin.x = updatedRect.origin.x.clamped(to: 0...(1 - updatedRect.width))
        updatedRect.origin.y = updatedRect.origin.y.clamped(to: 0...(1 - updatedRect.height))
        updateRegionRect(regionID: regionID, rect: updatedRect)
    }

    func beginResize(for regionID: UUID) {
        startGesture(for: regionID)
    }

    func resize(regionID: UUID, translation: CGSize, canvasSize: CGSize) {
        guard gestureRegionID == regionID, let baseline = gestureBaselineRect else { return }
        let widthDelta = translation.width / max(canvasSize.width, 1)
        let heightDelta = translation.height / max(canvasSize.height, 1)

        let minimumSize: CGFloat = 0.10
        var updatedRect = baseline
        updatedRect.size.width = max(minimumSize, baseline.width + widthDelta)
        updatedRect.size.height = max(minimumSize, baseline.height + heightDelta)
        updatedRect.size.width = min(updatedRect.width, 1 - updatedRect.minX)
        updatedRect.size.height = min(updatedRect.height, 1 - updatedRect.minY)

        updateRegionRect(regionID: regionID, rect: updatedRect)
    }

    func endGesture() {
        gestureBaselineRect = nil
        gestureRegionID = nil
        refreshPreview()
    }

    func export() async {
        guard !regions.isEmpty else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            let image = try await redactionService.renderFinalImage(from: originalImage, regions: regions)
            try await saveService.saveImage(image)
            alert = EditorAlert(
                title: "Saved to Photos",
                message: "Your redacted image was exported successfully and is now available in Photos.",
                action: .openPhotos
            )
        } catch {
            alert = EditorAlert(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private var snapshot: RedactionEditorSnapshot {
        RedactionEditorSnapshot(regions: regions, selectedRegionID: selectedRegionID)
    }

    private func captureHistory() {
        historyController.capture(snapshot)
    }

    private func apply(snapshot: RedactionEditorSnapshot) {
        regions = snapshot.regions
        selectedRegionID = snapshot.selectedRegionID
        refreshPreview()
    }

    private func startGesture(for regionID: UUID) {
        guard gestureRegionID != regionID else { return }
        selectRegion(regionID)
        captureHistory()
        gestureRegionID = regionID
        gestureBaselineRect = regions.first(where: { $0.id == regionID })?.normalizedRect
    }

    private func updateRegionRect(regionID: UUID, rect: CGRect) {
        guard var region = regions.first(where: { $0.id == regionID }) else { return }
        region.normalizedRect = rect.clampedToUnitSpace(minSize: 0.10)
        replace(region)
    }

    private func replace(_ region: RedactionRegion) {
        guard let index = regions.firstIndex(where: { $0.id == region.id }) else { return }
        regions[index] = region
    }

    private func refreshPreview() {
        previewTask?.cancel()

        guard !regions.isEmpty else {
            previewImage = originalImage
            return
        }

        let image = originalImage
        let currentRegions = regions

        previewTask = Task { [weak self] in
            guard let self else { return }

            do {
                let rendered = try await self.redactionService.renderPreviewImage(
                    from: image,
                    regions: currentRegions,
                    maximumDimension: 1400
                )

                guard !Task.isCancelled else { return }
                self.previewImage = rendered
            } catch {
                guard !Task.isCancelled else { return }
                self.alert = EditorAlert(
                    title: "Preview Error",
                    message: error.localizedDescription
                )
            }
        }
    }
}
