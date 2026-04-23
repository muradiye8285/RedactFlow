import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var homeViewModel = HomeViewModel(
        mediaPickerService: MediaPickerService(),
        limitedLibraryImportService: LimitedLibraryImportService(),
        photoLibraryPermissionService: PhotoLibraryPermissionService(),
        photoRedactionService: PhotoRedactionService(),
        videoRedactionService: VideoRedactionService(),
        photoLibrarySaveService: PhotoLibrarySaveService()
    )

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                HomeView(viewModel: homeViewModel)
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .background(AppTheme.Colors.screenBackground.ignoresSafeArea())
    }
}
