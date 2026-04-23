import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("RedactFlow processes edits entirely on your device. Photos and videos are not uploaded to any server, and the app does not include analytics, ads, or account tracking.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                PremiumCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Offline Processing")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("Photo and video redaction runs locally with Apple’s media frameworks so you can hide private details before sharing, even without an internet connection.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        settingsRow(title: "No Tracking", detail: "No analytics SDK, no ad network, no behavioral profiling.")
                        Divider().overlay(AppTheme.Colors.stroke)
                        settingsRow(title: "App Version", detail: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                        Divider().overlay(AppTheme.Colors.stroke)
                        settingsRow(title: "Support", detail: "gokce8535@gmail.com")
                        Divider().overlay(AppTheme.Colors.stroke)
                        settingsRow(title: "Restore Purchases", detail: "Placeholder only for future one-time purchase presentation.")
                            .opacity(0.7)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AppTheme.Colors.screenBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}
