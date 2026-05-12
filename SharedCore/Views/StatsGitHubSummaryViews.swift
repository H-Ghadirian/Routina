import SwiftUI

enum StatsGitHubSurfaceStyle {
    static func gradient(colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.08), Color.white.opacity(0.04)]
                : [Color.white.opacity(0.98), Color.white.opacity(0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct StatsGitHubCardsGrid<Content: View>: View {
    let horizontalSizeClass: UserInterfaceSizeClass?
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: horizontalSizeClass == .compact ? 160 : 220,
                        maximum: 280
                    ),
                    spacing: 14
                )
            ],
            spacing: 14,
            content: content
        )
    }
}

struct StatsGitHubSummaryCard: View {
    let icon: String
    let accent: Color
    let title: String
    let value: String
    let caption: String
    let accessibilityIdentifier: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .routinaGlassCard(cornerRadius: 14, tint: accent, tintOpacity: colorScheme == .dark ? 0.18 : 0.12)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .padding(18)
        .routinaGlassPanel(cornerRadius: 24, tint: accent, tintOpacity: colorScheme == .dark ? 0.12 : 0.08)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(value). \(caption)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct StatsGitHubInsightPill: View {
    let icon: String
    let text: String
    let colorScheme: ColorScheme

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .routinaGlassPill(tint: .secondary, tintOpacity: colorScheme == .dark ? 0.14 : 0.06)
    }
}
