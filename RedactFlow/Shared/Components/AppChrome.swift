import SwiftUI

struct PremiumCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(
        padding: CGFloat = AppTheme.Spacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppTheme.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(AppTheme.Colors.stroke, lineWidth: 1)
                    )
            )
    }
}

struct PrimaryActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: systemImage)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(accent)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct TrustBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.07))
                    .overlay(Capsule().stroke(AppTheme.Colors.stroke, lineWidth: 1))
            )
    }
}

struct ProcessingOverlay: View {
    let title: String
    let message: String
    let progress: Double?

    var body: some View {
        ZStack {
            Color.black.opacity(0.44)
                .ignoresSafeArea()

            PremiumCard(padding: 22) {
                VStack(spacing: 14) {
                    if let progress {
                        ProgressView(value: progress)
                            .tint(.white)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }

                    VStack(spacing: 6) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 260)
            }
        }
        .transition(.opacity)
    }
}
