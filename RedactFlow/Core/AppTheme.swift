import SwiftUI

enum AppTheme {
    enum Colors {
        static let backgroundTop = Color(red: 0.06, green: 0.07, blue: 0.10)
        static let backgroundBottom = Color(red: 0.01, green: 0.02, blue: 0.04)
        static let card = Color.white.opacity(0.07)
        static let cardElevated = Color.white.opacity(0.11)
        static let stroke = Color.white.opacity(0.10)
        static let accent = Color(red: 0.43, green: 0.69, blue: 1.0)
        static let accentSecondary = Color(red: 0.27, green: 0.88, blue: 0.84)
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.72)
        static let textTertiary = Color.white.opacity(0.48)
        static let destructive = Color(red: 1.0, green: 0.42, blue: 0.42)

        static let screenBackground = LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let heroGradient = LinearGradient(
            colors: [
                Color(red: 0.17, green: 0.27, blue: 0.40),
                Color(red: 0.10, green: 0.14, blue: 0.24),
                Color(red: 0.04, green: 0.06, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accentGradient = LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    enum Spacing {
        static let screenInset: CGFloat = 20
        static let cardPadding: CGFloat = 18
        static let sectionGap: CGFloat = 18
        static let controlGap: CGFloat = 12
    }
}
