import SwiftUI

struct StatsAchievementsSection: View {
    let achievements: [StatsAchievementProgress]
    let earnedAchievementIDsByPeriod: [StatsAchievementCelebrationPeriod: Set<String>]
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme
    @State private var selectedDomain = StatsAchievementDomain.all
    @State private var selectedStatus = StatsAchievementStatusFilter.inProgress
    @State private var selectedEarnedPeriod = StatsAchievementCelebrationPeriod.today

    private var filteredAchievements: [StatsAchievementProgress] {
        achievements.filter { achievement in
            selectedDomain == .all || achievement.domain == selectedDomain
        }
    }

    private var filteredEarnedCount: Int {
        StatsAchievementStats.earnedCount(in: filteredAchievements)
    }

    private var visibleAchievements: [StatsAchievementProgress] {
        switch selectedStatus {
        case .inProgress:
            return filteredAchievements.filter { !$0.isEarned }
        case .achieved:
            let earnedAchievementIDs = earnedAchievementIDsByPeriod[selectedEarnedPeriod] ?? []
            return filteredAchievements.filter { achievement in
                achievement.isEarned && earnedAchievementIDs.contains(achievement.id)
            }
        }
    }

    private var visibleGroup: StatsAchievementDisplayGroup {
        StatsAchievementDisplayGroup(
            title: selectedStatus.groupTitle(period: selectedEarnedPeriod),
            systemImage: selectedStatus.systemImage,
            achievements: visibleAchievements
        )
    }

    private var emptyTitle: String {
        switch selectedStatus {
        case .inProgress:
            return "No in-progress badges"
        case .achieved:
            return "No badges achieved \(selectedEarnedPeriod.emptyStateSuffix)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Achievements",
                subtitle: "All-time badges earned from focus, sleep, away, done, emotion, place, goal, and note history."
            ) {
                StatsSmallHighlightBadge(
                    title: "Earned",
                    value: "\(filteredEarnedCount)/\(filteredAchievements.count)",
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            categoryPicker

            statusPicker

            if selectedStatus == .achieved {
                achievedPeriodPicker
            }

            if visibleAchievements.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: selectedStatus.emptyStateSystemImage)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                StatsAchievementGroupView(
                    group: visibleGroup,
                    badgeColumns: badgeColumns,
                    colorScheme: colorScheme
                )
            }
        }
        .onChange(of: selectedStatus) { _, status in
            if status == .achieved {
                selectedEarnedPeriod = .today
            }
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats.achievements.section")
    }

    private var categoryPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Achievement category",
            options: StatsAchievementDomain.allCases,
            selection: $selectedDomain,
            fillsAvailableWidth: true
        ) { domain in
            Text(domain.title)
        }
        .frame(maxWidth: 860)
        .accessibilityIdentifier("stats.achievements.categoryPicker")
    }

    private var statusPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Achievement status",
            options: StatsAchievementStatusFilter.allCases,
            selection: $selectedStatus,
            fillsAvailableWidth: true
        ) { status in
            Text(status.title)
        }
        .frame(maxWidth: 360)
        .accessibilityIdentifier("stats.achievements.statusPicker")
    }

    private var achievedPeriodPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Achieved period",
            options: StatsAchievementCelebrationPeriod.allCases,
            selection: $selectedEarnedPeriod,
            fillsAvailableWidth: true
        ) { period in
            Text(period.title)
        }
        .frame(maxWidth: 560)
        .accessibilityIdentifier("stats.achievements.achievedPeriodPicker")
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

private enum StatsAchievementStatusFilter: String, CaseIterable, Identifiable {
    case inProgress
    case achieved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inProgress:
            return "In Progress"
        case .achieved:
            return "Achieved"
        }
    }

    var systemImage: String {
        switch self {
        case .inProgress:
            return "clock.fill"
        case .achieved:
            return "checkmark.seal.fill"
        }
    }

    var emptyStateSystemImage: String {
        switch self {
        case .inProgress:
            return "checkmark.seal"
        case .achieved:
            return "medal"
        }
    }

    func groupTitle(period: StatsAchievementCelebrationPeriod) -> String {
        switch self {
        case .inProgress:
            return "In Progress"
        case .achieved:
            return "Achieved \(period.title)"
        }
    }
}

private extension StatsAchievementCelebrationPeriod {
    var emptyStateSuffix: String {
        switch self {
        case .today:
            return "today"
        case .week:
            return "this week"
        case .month:
            return "this month"
        case .year:
            return "this year"
        }
    }
}

struct StatsRecentWinsSection: View {
    let celebrations: [StatsAchievementCelebration]
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Recent Wins",
                subtitle: "Today, this week, this month, and this year accomplishments."
            ) {
                StatsSmallHighlightBadge(
                    title: "Periods",
                    value: "\(celebrations.count)",
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            if celebrations.isEmpty {
                ContentUnavailableView("No recent wins yet", systemImage: "party.popper")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                StatsAchievementCelebrationsView(
                    celebrations: celebrations,
                    columns: celebrationColumns,
                    colorScheme: colorScheme
                )
            }
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats.recentWins.section")
    }

    private var celebrationColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 220, maximum: 340),
                spacing: 12,
                alignment: .topLeading
            ),
        ]
    }
}

private struct StatsAchievementCelebrationsView: View {
    let celebrations: [StatsAchievementCelebration]
    let columns: [GridItem]
    let colorScheme: ColorScheme

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(celebrations) { celebration in
                StatsAchievementCelebrationCard(
                    celebration: celebration,
                    colorScheme: colorScheme
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats.recentWins.grid")
    }
}

private struct StatsAchievementCelebrationCard: View {
    let celebration: StatsAchievementCelebration
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: celebration.period.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 36, height: 36)
                    .routinaGlassCard(
                        cornerRadius: 12,
                        tint: .orange,
                        tintOpacity: colorScheme == .dark ? 0.18 : 0.12
                    )

                Text(celebration.period.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(celebration.highlights) { highlight in
                    StatsAchievementCelebrationHighlightRow(
                        highlight: highlight,
                        colorScheme: colorScheme
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.orange.opacity(colorScheme == .dark ? 0.28 : 0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(celebration.period.title)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        celebration.highlights
            .map { "\($0.title): \($0.value)" }
            .joined(separator: ". ")
    }
}

private struct StatsAchievementCelebrationHighlightRow: View {
    let highlight: StatsAchievementCelebrationHighlight
    let colorScheme: ColorScheme

    private var accent: Color {
        highlight.domain.accentColor
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: highlight.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .routinaGlassCard(
                    cornerRadius: 8,
                    tint: accent,
                    tintOpacity: colorScheme == .dark ? 0.16 : 0.1
                )

            Text(highlight.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(highlight.value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct StatsAchievementDisplayGroup: Identifiable {
    let title: String
    let systemImage: String
    let achievements: [StatsAchievementProgress]

    var id: String { title }
}

private struct StatsAchievementGroupView: View {
    let group: StatsAchievementDisplayGroup
    let badgeColumns: [GridItem]
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: group.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(group.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("\(group.achievements.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(colorScheme == .dark ? 0.14 : 0.08))
                    )

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: badgeColumns, alignment: .leading, spacing: 12) {
                ForEach(group.achievements) { achievement in
                    StatsAchievementBadgeCard(
                        achievement: achievement,
                        colorScheme: colorScheme
                    )
                }
            }
        }
    }
}

private struct StatsAchievementBadgeCard: View {
    let achievement: StatsAchievementProgress
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

private extension StatsAchievementDomain {
    var accentColor: Color {
        switch self {
        case .all:
            return .accentColor
        case .focus:
            return .teal
        case .sleep:
            return .purple
        case .away:
            return .cyan
        case .done:
            return .green
        case .emotions:
            return .pink
        case .places:
            return .teal
        case .goals:
            return .yellow
        case .notes:
            return .blue
        }
    }
}

private extension StatsAchievementCategory {
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
        case .sleep:
            return .purple
        case .sleepStreak:
            return .indigo
        case .away:
            return .cyan
        case .done:
            return .green
        case .doneStreak:
            return .orange
        case .emotion:
            return .pink
        case .emotionStreak:
            return .red
        case .place:
            return .cyan
        case .placeStreak:
            return .teal
        case .goal:
            return .yellow
        case .note:
            return .blue
        case .noteStreak:
            return .indigo
        }
    }
}
