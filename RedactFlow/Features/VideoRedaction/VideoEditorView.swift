import AVKit
import SwiftUI

struct VideoEditorView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                previewCard
                playbackCard
                inspectorCard
                actionCard
            }
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(AppTheme.Colors.screenBackground.ignoresSafeArea())
        .navigationTitle("Redact Video")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
                .disabled(viewModel.isExporting)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Export") {
                    Task {
                        await viewModel.export()
                    }
                }
                .fontWeight(.semibold)
                .disabled(!viewModel.hasRegions || viewModel.isExporting)
            }
        }
        .overlay {
            if viewModel.isExporting {
                ProcessingOverlay(
                    title: "Exporting Video",
                    message: "Applying redactions across the full clip and saving to Photos.",
                    progress: viewModel.exportProgress
                )
            }
        }
        .alert(item: $viewModel.alert) { alert in
            switch alert.action {
            case .dismiss, .openSettings:
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            case .openPhotos:
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Open Photos")) {
                        openPhotosApp()
                    },
                    secondaryButton: .cancel(Text("Stay Here"))
                )
            }
        }
    }

    private var previewCard: some View {
        PremiumCard(padding: 14) {
            ZStack {
                RegionEditingCanvas(
                    mediaSize: viewModel.canvasSize,
                    regions: viewModel.regions,
                    selectedRegionID: viewModel.selectedRegionID,
                    isInteractionEnabled: !viewModel.isExporting,
                    onSelectRegion: viewModel.selectRegion(_:),
                    onBeginMove: viewModel.beginMove(for:),
                    onMove: viewModel.move(regionID:translation:canvasSize:),
                    onBeginResize: viewModel.beginResize(for:),
                    onResize: viewModel.resize(regionID:translation:canvasSize:),
                    onEndGesture: viewModel.endGesture
                ) {
                    PlayerSurfaceView(player: viewModel.player)
                }
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if !viewModel.hasRegions {
                    emptyHint(
                        title: "Add your first region",
                        message: "Regions in V1 apply to the full clip. Position them over the area you want to hide."
                    )
                    .padding(18)
                }
            }
        }
    }

    private var playbackCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Playback")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 14) {
                    Button {
                        viewModel.togglePlayback()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 42, height: 42)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { viewModel.currentTime },
                                set: { viewModel.scrub(to: $0) }
                            ),
                            in: 0...viewModel.duration
                        )
                        .tint(.white)

                        HStack {
                            Text(formattedTime(viewModel.currentTime))
                            Spacer()
                            Text(formattedTime(viewModel.duration))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                Text("Redaction regions in this version stay active for the entire video duration.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private var inspectorCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Region Controls")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(viewModel.selectedRegion == nil ? "Select a region to edit its style and strength." : "Tune the selected region.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Button("Add Region") {
                        viewModel.addRegion()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                }

                styleRow

                if let selectedRegion = viewModel.selectedRegion {
                    if selectedRegion.style.supportsIntensity {
                        sliderRow(
                            title: "Intensity",
                            value: selectedRegion.intensity,
                            range: 0...1,
                            action: viewModel.updateSelectedIntensity(_:)
                        )
                    }

                    sliderRow(
                        title: "Corner Radius",
                        value: selectedRegion.cornerRadius,
                        range: 0...0.5,
                        action: viewModel.updateSelectedCornerRadius(_:)
                    )
                }
            }
        }
    }

    private var styleRow: some View {
        HStack(spacing: 10) {
            ForEach(RedactionStyle.allCases) { style in
                Button {
                    viewModel.updateSelectedStyle(style)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: style.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                        Text(style.title)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(
                        viewModel.selectedRegion?.style == style ? Color.black : Color.white
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                viewModel.selectedRegion?.style == style
                                    ? AnyShapeStyle(Color.white)
                                    : AnyShapeStyle(Color.white.opacity(0.06))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.Colors.stroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedRegion == nil)
            }
        }
    }

    private var actionCard: some View {
        PremiumCard {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    actionButton(title: "Undo", systemImage: "arrow.uturn.backward", isEnabled: viewModel.canUndo) {
                        viewModel.undo()
                    }
                    actionButton(title: "Redo", systemImage: "arrow.uturn.forward", isEnabled: viewModel.canRedo) {
                        viewModel.redo()
                    }
                }

                HStack(spacing: 10) {
                    actionButton(title: "Delete", systemImage: "trash", tint: AppTheme.Colors.destructive, isEnabled: viewModel.selectedRegion != nil) {
                        viewModel.deleteSelectedRegion()
                    }
                    actionButton(title: "Reset All", systemImage: "xmark.circle", isEnabled: viewModel.hasRegions) {
                        viewModel.resetAll()
                    }
                }
            }
        }
    }

    private func sliderRow(
        title: String,
        value: Double,
        range: ClosedRange<Double>,
        action: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int((value / range.upperBound) * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Slider(value: Binding(get: { value }, set: action), in: range)
                .tint(.white)
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color = .white,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? tint : AppTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(isEnabled ? 0.08 : 0.03))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func emptyHint(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.black.opacity(0.56))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func formattedTime(_ value: Double) -> String {
        let totalSeconds = Int(value.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }

    private func openPhotosApp() {
        guard let url = URL(string: "photos-redirect://") else { return }
        UIApplication.shared.open(url)
    }
}

private struct PlayerSurfaceView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player
    }
}

private final class PlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}
