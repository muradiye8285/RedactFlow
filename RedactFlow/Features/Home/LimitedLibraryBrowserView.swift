import Photos
import PhotosUI
import SwiftUI

struct LimitedLibraryBrowserView: View {
    @ObservedObject var viewModel: LimitedLibraryBrowserViewModel
    let onClose: () -> Void
    let onSelectionUpdated: () -> Void
    let onOpenSettings: () -> Void
    let onPicked: (MediaLibraryPickerResult) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var isPresentingLimitedPicker = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sectionGap) {
                    introCard

                    if viewModel.assets.isEmpty, !viewModel.isLoadingAssets {
                        emptyStateCard
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(viewModel.assets) { asset in
                                assetTile(asset)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.screenInset)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .background(AppTheme.Colors.screenBackground.ignoresSafeArea())
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .background(
                LimitedLibraryPickerPresenter(isPresented: $isPresentingLimitedPicker) {
                    viewModel.loadAssets()
                    onSelectionUpdated()
                }
                .frame(width: 0, height: 0)
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        onClose()
                    }
                    .disabled(viewModel.isImportingSelection)
                }
            }
            .overlay {
                if viewModel.isLoadingAssets {
                    ProcessingOverlay(
                        title: "Loading Library",
                        message: "Reading the items you've allowed to RedactFlow.",
                        progress: nil
                    )
                } else if viewModel.isImportingSelection {
                    ProcessingOverlay(
                        title: "Opening Item",
                        message: "Preparing your selection securely on-device.",
                        progress: nil
                    )
                }
            }
            .alert(item: $viewModel.alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .task {
                viewModel.loadAssets()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                viewModel.loadAssets()
            }
        }
    }

    private var introCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Limited Access Import")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(viewModel.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack(spacing: 10) {
                    Button("Update Selection") {
                        isPresentingLimitedPicker = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .disabled(isPresentingLimitedPicker)

                    Button("Open Settings") {
                        onOpenSettings()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var emptyStateCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.emptyTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(viewModel.emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private func assetTile(_ asset: LimitedLibraryAsset) -> some View {
        Button {
            Task {
                guard let result = await viewModel.importAsset(asset) else { return }
                onPicked(result)
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                LimitedLibraryThumbnailView(
                    asset: asset,
                    viewModel: viewModel
                )

                if let durationText = asset.durationText {
                    Text(durationText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.68))
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.Colors.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isImportingSelection)
    }
}

private struct LimitedLibraryThumbnailView: View {
    let asset: LimitedLibraryAsset
    @ObservedObject var viewModel: LimitedLibraryBrowserViewModel

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .clipped()
        .task(id: asset.id) {
            if image == nil {
                image = await viewModel.thumbnail(
                    for: asset,
                    targetSize: CGSize(width: 420, height: 420)
                )
            }
        }
    }
}

private struct LimitedLibraryPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onComplete: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.isHidden = true
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, !context.coordinator.isPresenting else { return }
        context.coordinator.isPresenting = true

        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: uiViewController)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            context.coordinator.isPresenting = false
            isPresented = false
            onComplete()
        }
    }

    final class Coordinator {
        var isPresenting = false
    }
}
