import SwiftUI

struct StatsFocusAchievementsSection: View {
    let achievements: [FocusAchievementProgress]
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    private var earnedCount: Int {
        FocusAchievementStats.earnedCount(in: achievements)
    }

    private var displayAchievements: [FocusAchievementProgress] {
        FocusAchievementStats.displayOrdered(achievements)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Focus achievements",
                subtitle: "All-time badges earned from completed focus sessions."
            ) {
                StatsSmallHighlightBadge(
                    title: "Earned",
                    value: "\(earnedCount)/\(achievements.count)",
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            LazyVGrid(columns: badgeColumns, alignment: .leading, spacing: 12) {
                ForEach(displayAchievements) { achievement in
                    FocusAchievementBadgeCard(
                        achievement: achievement,
                        colorScheme: colorScheme
                    )
                }
            }
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats.focusAchievements.section")
    }

    private var badgeColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 210, maximum: 320),
                spacing: 12,
                alignment: .topLeading
            ),
        ]
    }
}

private struct FocusAchievementBadgeCard: View {
    let achievement: FocusAchievementProgress
    let colorScheme: ColorScheme

    private var accent: Color {
        achievement.category.accentColor
    }

    private var statusText: String {
        achievement.isEarned ? "Earned" : "In progress"
    }

    private var statusImage: String {
        achievement.isEarned ? "checkmark.seal.fill" : "lock.open"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: achievement.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(achievement.isEarned ? accent : .secondary)
                    .frame(width: 42, height: 42)
                    .routinaGlassCard(
                        cornerRadius: 14,
                        tint: achievement.isEarned ? accent : .secondary,
                        tintOpacity: achievement.isEarned ? 0.18 : 0.08
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(achievement.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(statusText, systemImage: statusImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(achievement.isEarned ? accent : .secondary)
                }

                Spacer(minLength: 0)
            }

            Text(achievement.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 7) {
                ProgressView(value: achievement.progress)
                    .tint(achievement.isEarned ? accent : .secondary)

                Text(achievement.progressText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .opacity(achievement.isEarned ? 1 : 0.78)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(achievement.title)
        .accessibilityValue("\(statusText). \(achievement.progressText). \(achievement.subtitle)")
    }

    private var cardFill: Color {
        if achievement.isEarned {
            return accent.opacity(colorScheme == .dark ? 0.14 : 0.08)
        }
        return Color.secondary.opacity(colorScheme == .dark ? 0.1 : 0.055)
    }

    private var strokeColor: Color {
        if achievement.isEarned {
            return accent.opacity(colorScheme == .dark ? 0.32 : 0.22)
        }
        return Color.secondary.opacity(colorScheme == .dark ? 0.24 : 0.16)
    }
}

private extension FocusAchievementCategory {
    var accentColor: Color {
        switch self {
        case .total:
            return .teal
        case .blocks:
            return .mint
        case .streak:
            return .orange
        case .session:
            return .blue
        case .daily:
            return .indigo
        case .weekly:
            return .green
        case .comeback:
            return .pink
        }
    }
}
