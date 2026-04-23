import AVFoundation
import SwiftUI

@MainActor
final class VideoEditorViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let player: AVPlayer
    let video: PickedVideo

    @Published private(set) var regions: [RedactionRegion] = []
    @Published private(set) var selectedRegionID: UUID?
    @Published var currentTime: Double = 0
    @Published var isPlaying = false
    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var alert: EditorAlert?

    private let redactionService: VideoRedactionService
    private let saveService: PhotoLibrarySaveService
    private let historyController = RedactionHistoryController()

    private var gestureBaselineRect: CGRect?
    private var gestureRegionID: UUID?
    private var timeObserverToken: Any?
    private var playbackEndObserver: Any?

    init(
        video: PickedVideo,
        redactionService: VideoRedactionService,
        saveService: PhotoLibrarySaveService
    ) {
        self.video = video
        self.redactionService = redactionService
        self.saveService = saveService
        self.player = AVPlayer(url: video.url)
        configurePlaybackObservers()
    }

    deinit {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }

        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }
    }

    var canvasSize: CGSize {
        video.displaySize
    }

    var duration: Double {
        max(video.duration, 0.1)
    }

    var selectedRegion: RedactionRegion? {
        guard let selectedRegionID else { return nil }
        return regions.first(where: { $0.id == selectedRegionID })
    }

    var canUndo: Bool { historyController.canUndo }
    var canRedo: Bool { historyController.canRedo }
    var hasRegions: Bool { !regions.isEmpty }

    func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func scrub(to time: Double) {
        currentTime = time
        player.seek(
            to: CMTime(seconds: time, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

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
    }

    func updateSelectedIntensity(_ intensity: Double) {
        guard var region = selectedRegion else { return }
        captureHistory()
        region.intensity = intensity.clamped(to: 0...1)
        replace(region)
    }

    func updateSelectedCornerRadius(_ radius: Double) {
        guard var region = selectedRegion else { return }
        captureHistory()
        region.cornerRadius = radius.clamped(to: 0...0.5)
        replace(region)
    }

    func deleteSelectedRegion() {
        guard let selectedRegionID else { return }
        captureHistory()
        regions.removeAll(where: { $0.id == selectedRegionID })
        self.selectedRegionID = regions.last?.id
    }

    func resetAll() {
        guard !regions.isEmpty else { return }
        captureHistory()
        regions.removeAll()
        selectedRegionID = nil
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
    }

    func export() async {
        guard !regions.isEmpty else { return }
        isExporting = true
        exportProgress = 0.02
        player.pause()
        isPlaying = false

        defer { isExporting = false }

        do {
            let outputURL = try await redactionService.exportVideo(
                asset: AVURLAsset(url: video.url),
                regions: regions
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.exportProgress = max(progress, 0.02)
                }
            }

            try await saveService.saveVideo(at: outputURL)
            alert = EditorAlert(
                title: "Saved to Photos",
                message: "Your redacted video was exported successfully and is now available in Photos.",
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

    private func configurePlaybackObservers() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds.isFinite ? time.seconds : 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = min(self.duration, max(seconds, 0))
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.player.seek(to: .zero)
                self.isPlaying = false
                self.currentTime = 0
            }
        }
    }
}
