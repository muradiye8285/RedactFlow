import Photos
import PhotosUI
import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    @State private var isPickerPresented = false
    @State private var activePickerKind: HomePickerKind = .photo
    @State private var pendingPickerResult: MediaLibraryPickerResult?
    @State private var photoEditorViewModel: PhotoEditorViewModel?
    @State private var videoEditorViewModel: VideoEditorViewModel?
    @State private var limitedLibraryViewModel: LimitedLibraryBrowserViewModel?
    @State private var isPhotoEditorPresented = false
    @State private var isVideoEditorPresented = false
    @State private var isResolvingPickerResult = false
    @State private var isLimitedLibraryPresented = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sectionGap) {
                    heroCard
                    if viewModel.hasLimitedPhotoAccess {
                        limitedAccessCard
                    }

                    VStack(spacing: 14) {
                        PrimaryActionCard(
                            title: "Redact Photo",
                            subtitle: "Blur, pixelate, or cover private details before you share.",
                            systemImage: "photo.fill",
                            accent: LinearGradient(
                                colors: [
                                    Color(red: 0.18, green: 0.33, blue: 0.48),
                                    Color(red: 0.09, green: 0.16, blue: 0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) {
                            Task {
                                await openPicker(for: .photo)
                            }
                        }

                        PrimaryActionCard(
                            title: "Redact Video",
                            subtitle: "Apply clean redaction regions across the full clip, fully on-device.",
                            systemImage: "video.fill",
                            accent: LinearGradient(
                                colors: [
                                    Color(red: 0.18, green: 0.20, blue: 0.34),
                                    Color(red: 0.08, green: 0.09, blue: 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) {
                            Task {
                                await openPicker(for: .video)
                            }
                        }
                    }

                    PremiumCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Built for privacy-sensitive screenshots, photos, and videos.")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text("RedactFlow keeps the entire edit pipeline on your iPhone. No cloud upload, no analytics, no account system.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.screenInset)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .background(AppTheme.Colors.screenBackground.ignoresSafeArea())
            .navigationTitle("RedactFlow")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.refreshPermissionState()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $isPickerPresented) {
                MediaLibraryPicker(
                    kind: activePickerKind,
                    onDismissRequested: {
                        isPickerPresented = false
                    },
                    onResult: { result in
                        pendingPickerResult = result
                        Task {
                            await presentPendingPickerResultIfPossible()
                        }
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isLimitedLibraryPresented) {
                if let limitedLibraryViewModel {
                    LimitedLibraryBrowserView(
                        viewModel: limitedLibraryViewModel,
                        onClose: {
                            isLimitedLibraryPresented = false
                        },
                        onSelectionUpdated: {
                            viewModel.refreshPermissionState()
                        },
                        onOpenSettings: {
                            openAppSettings()
                        },
                        onPicked: { result in
                            pendingPickerResult = result
                            isLimitedLibraryPresented = false
                            Task {
                                await presentPendingPickerResultIfPossible()
                            }
                        }
                    )
                }
            }
            .onChange(of: isPickerPresented) { _, isPresented in
                guard !isPresented else { return }
                Task {
                    await presentPendingPickerResultIfPossible()
                }
            }
            .onChange(of: isLimitedLibraryPresented) { _, isPresented in
                guard !isPresented else { return }
                Task {
                    await presentPendingPickerResultIfPossible()
                    if !isLimitedLibraryPresented {
                        limitedLibraryViewModel = nil
                    }
                }
            }
            .navigationDestination(isPresented: $isPhotoEditorPresented) {
                if let editorViewModel = photoEditorViewModel {
                    PhotoEditorView(viewModel: editorViewModel)
                        .onDisappear {
                            photoEditorViewModel = nil
                        }
                }
            }
            .navigationDestination(isPresented: $isVideoEditorPresented) {
                if let editorViewModel = videoEditorViewModel {
                    VideoEditorView(viewModel: editorViewModel)
                        .onDisappear {
                            videoEditorViewModel = nil
                        }
                }
            }
            .overlay {
                if viewModel.isPreparingMedia {
                    ProcessingOverlay(
                        title: "Preparing",
                        message: "Loading your media securely on-device.",
                        progress: nil
                    )
                }
            }
            .alert(item: $viewModel.alert) { alert in
                switch alert.action {
                case .dismiss, .openPhotos:
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("OK"))
                    )
                case .openSettings:
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        primaryButton: .default(Text("Settings")) {
                            openAppSettings()
                        },
                        secondaryButton: .cancel(Text("OK"))
                    )
                }
            }
        }
    }

    private var limitedAccessCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Limited Photos Access")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("You’re using limited library access. RedactFlow will open a built-in import browser so you can pick from the items you've explicitly allowed.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack(spacing: 10) {
                    Button("Update Selection") {
                        presentLimitedLibraryPicker()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(Capsule())

                    Button("Open Settings") {
                        openAppSettings()
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

    private var heroCard: some View {
        PremiumCard(padding: 22) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Hide private details fast.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("A focused offline utility for screenshots, photos, and videos that need safe redaction before sharing.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                FlowLayout(spacing: 10) {
                    TrustBadge(title: "Fully Offline")
                    TrustBadge(title: "No Tracking")
                    TrustBadge(title: "One-Time Purchase")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppTheme.Colors.heroGradient)
            )
        }
    }

    private func openPicker(for kind: HomePickerKind) async {
        guard await viewModel.requestAccessAndPreparePicker(for: kind) else { return }
        activePickerKind = kind
        pendingPickerResult = nil
        photoEditorViewModel = nil
        videoEditorViewModel = nil
        limitedLibraryViewModel = nil
        isPhotoEditorPresented = false
        isVideoEditorPresented = false

        if viewModel.hasLimitedPhotoAccess {
            limitedLibraryViewModel = viewModel.makeLimitedLibraryBrowserViewModel(for: kind)
            isLimitedLibraryPresented = true
        } else {
            isPickerPresented = true
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first(where: \.isKeyWindow)?.rootViewController,
              let presentingViewController = topViewController(from: rootViewController)
        else { return }

        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presentingViewController)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            limitedLibraryViewModel?.loadAssets()
            viewModel.refreshPermissionState()
        }
    }

    private func topViewController(from viewController: UIViewController) -> UIViewController? {
        if let presented = viewController.presentedViewController {
            return topViewController(from: presented)
        }

        if let navigationController = viewController as? UINavigationController {
            return navigationController.visibleViewController.flatMap(topViewController(from:))
                ?? navigationController
        }

        if let tabBarController = viewController as? UITabBarController {
            return tabBarController.selectedViewController.flatMap(topViewController(from:))
                ?? tabBarController
        }

        return viewController
    }

    @MainActor
    private func presentPendingPickerResultIfPossible() async {
        guard !isPickerPresented, !isLimitedLibraryPresented, !isResolvingPickerResult else { return }

        guard let pendingPickerResult else {
            return
        }

        isResolvingPickerResult = true
        self.pendingPickerResult = nil
        defer { isResolvingPickerResult = false }

        try? await Task.sleep(for: .milliseconds(150))

        switch pendingPickerResult {
        case .photo(let image):
            photoEditorViewModel = await viewModel.makePhotoEditor(from: image)
            isPhotoEditorPresented = photoEditorViewModel != nil
        case .video(let url):
            videoEditorViewModel = await viewModel.makeVideoEditor(from: url)
            isVideoEditorPresented = videoEditorViewModel != nil
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
