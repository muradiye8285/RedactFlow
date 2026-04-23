import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Hide private details fast",
            message: "Redact sensitive details before you post, send, or archive screenshots and photos.",
            systemImage: "hand.raised.square.on.square",
            gradient: [Color(red: 0.24, green: 0.42, blue: 0.60), Color(red: 0.10, green: 0.16, blue: 0.28)]
        ),
        OnboardingPage(
            title: "Blur, pixelate, or cover",
            message: "Add multiple rectangular regions, fine-tune intensity, and choose clean black bars when clarity matters.",
            systemImage: "square.and.pencil.circle.fill",
            gradient: [Color(red: 0.23, green: 0.28, blue: 0.52), Color(red: 0.10, green: 0.10, blue: 0.20)]
        ),
        OnboardingPage(
            title: "Fully offline",
            message: "Your media stays on-device. No tracking, no analytics, no cloud processing.",
            systemImage: "lock.shield.fill",
            gradient: [Color(red: 0.14, green: 0.40, blue: 0.38), Color(red: 0.05, green: 0.12, blue: 0.14)]
        ),
        OnboardingPage(
            title: "Share safely",
            message: "Export a cleaned result back to Photos when you’re ready to share with confidence.",
            systemImage: "square.and.arrow.up.fill",
            gradient: [Color(red: 0.33, green: 0.25, blue: 0.18), Color(red: 0.12, green: 0.09, blue: 0.06)]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page: page)
                        .tag(index)
                        .padding(.horizontal, AppTheme.Spacing.screenInset)
                        .padding(.top, 12)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
        }
        .background(AppTheme.Colors.screenBackground.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Text("Welcome")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Spacer()

            Button("Skip") {
                onFinish()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, AppTheme.Spacing.screenInset)
        .padding(.top, 18)
    }

    private func pageView(page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(colors: page.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(height: 320)
                .overlay {
                    VStack(alignment: .leading, spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 72, height: 72)

                            Image(systemName: page.systemImage)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Text(page.title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(page.message)
                            .font(.headline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.18))
                        .frame(width: index == currentPage ? 28 : 10, height: 10)
                }
            }

            PremiumCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What you can expect")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("RedactFlow is built as a fast, premium utility for manual privacy redaction. It does not upload your media and it does not use AI detection.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                if currentPage == pages.count - 1 {
                    onFinish()
                } else {
                    withAnimation(.snappy(duration: 0.28)) {
                        currentPage += 1
                    }
                }
            } label: {
                Text(currentPage == pages.count - 1 ? "Start Editing" : "Continue")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if currentPage > 0 {
                Button("Back") {
                    withAnimation(.snappy(duration: 0.28)) {
                        currentPage -= 1
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.screenInset)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
}

private struct OnboardingPage {
    let title: String
    let message: String
    let systemImage: String
    let gradient: [Color]
}
