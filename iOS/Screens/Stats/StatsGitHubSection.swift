import Foundation
import SwiftUI

struct StatsGitHubSection: View {
    let connection: GitHubConnectionStatus
    let stats: GitHubStatsSnapshot?
    let errorMessage: String?
    let isLoading: Bool
    let selectedRange: DoneChartRange
    let horizontalSizeClass: UserInterfaceSizeClass?
    let colorScheme: ColorScheme
    let calendar: Calendar
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            content
        }
        .padding(20)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GitHub activity")
                    .font(.title3.weight(.semibold))

                Text(sectionSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if connection.isConnected {
                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            HStack(spacing: 12) {
                ProgressView()
                Text("Loading GitHub stats...")
                    .foregroundStyle(.secondary)
            }
        } else if let stats {
            switch stats {
            case let .repository(stats):
                repositoryContent(stats)
            case let .profile(stats):
                profileContent(stats)
            }
        } else if let errorMessage {
            VStack(alignment: .leading, spacing: 12) {
                Text(errorMessage)
                    .foregroundStyle(.secondary)

                Button(action: onRefresh) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(!connection.isConnected)
            }
        } else {
            Text(emptyStateText)
                .foregroundStyle(.secondary)
        }
    }

    private var sectionSubtitle: String {
        if let repository = connection.repository {
            return "Repo: \(repository.fullName)"
        }
        if let viewerLogin = connection.viewerLogin, !viewerLogin.isEmpty {
            return "Profile: @\(viewerLogin)"
        }
        if connection.scope == .profile {
            return "No profile connected"
        }
        return "No repository connected"
    }

    private var emptyStateText: String {
        connection.scope == .profile
            ? "Connect your GitHub profile in Settings to show overall contributions, commits, reviews, and issue activity here."
            : "Connect a GitHub repository in Settings to show commits, pull requests, and contributor activity here."
    }

    @ViewBuilder
    private func repositoryContent(_ stats: GitHubRepositoryStats) -> some View {
        cardsGrid {
            gitHubSummaryCard(
                icon: "point.topleft.down.curvedto.point.bottomright.up.fill",
                accent: .indigo,
                title: "Commits",
                value: stats.totalCommitCount.formatted(),
                caption: stats.repository.fullName,
                accessibilityIdentifier: "stats.github.commits"
            )

            gitHubSummaryCard(
                icon: "arrow.merge",
                accent: .green,
                title: "Merged PRs",
                value: stats.mergedPullRequestCount.formatted(),
                caption: selectedRange.periodDescription,
                accessibilityIdentifier: "stats.github.mergedPRs"
            )

            gitHubSummaryCard(
                icon: "tray.full.fill",
                accent: .orange,
                title: "Open PRs",
                value: stats.openPullRequestCount.formatted(),
                caption: "Current open pull requests",
                accessibilityIdentifier: "stats.github.openPRs"
            )

            gitHubSummaryCard(
                icon: "person.2.fill",
                accent: .blue,
                title: "Contributors",
                value: stats.contributorCount.formatted(),
                caption: "Active in this range",
                accessibilityIdentifier: "stats.github.contributors"
            )
        }

        if selectedRange != .today {
            gitHubChart(
                points: stats.commitPoints,
                averageCount: stats.averageCommitCount,
                busiestDay: stats.busiestCommitDay,
                yAxisLabel: "Commits",
                averageLabel: "Average"
            )

            HStack(spacing: 10) {
                bottomInsightPill(icon: "calendar", text: selectedRange.periodDescription)

                if let busiestCommitDay = stats.busiestCommitDay {
                    bottomInsightPill(icon: "sparkles", text: "Best day: \(StatsGitHubChartPresentation.bestDayCaption(for: busiestCommitDay))")
                } else {
                    bottomInsightPill(icon: "arrow.trianglehead.2.clockwise.rotate.90", text: "No commits in this range")
                }
            }
        }
    }

    @ViewBuilder
    private func profileContent(_ stats: GitHubProfileStats) -> some View {
        cardsGrid {
            gitHubSummaryCard(
                icon: "chart.bar.xaxis",
                accent: .indigo,
                title: "Contributions",
                value: stats.totalContributionCount.formatted(),
                caption: "@\(stats.login) across GitHub",
                accessibilityIdentifier: "stats.github.profile.contributions"
            )

            gitHubSummaryCard(
                icon: "point.topleft.down.curvedto.point.bottomright.up.fill",
                accent: .blue,
                title: "Commits",
                value: stats.totalCommitCount.formatted(),
                caption: selectedRange.periodDescription,
                accessibilityIdentifier: "stats.github.profile.commits"
            )

            gitHubSummaryCard(
                icon: "arrow.triangle.pull",
                accent: .green,
                title: "Pull Requests",
                value: stats.totalPullRequestCount.formatted(),
                caption: "Opened in this range",
                accessibilityIdentifier: "stats.github.profile.pullRequests"
            )

            gitHubSummaryCard(
                icon: "text.bubble.fill",
                accent: .orange,
                title: "Reviews",
                value: stats.totalPullRequestReviewCount.formatted(),
                caption: "Review contributions",
                accessibilityIdentifier: "stats.github.profile.reviews"
            )

            gitHubSummaryCard(
                icon: "exclamationmark.circle.fill",
                accent: .pink,
                title: "Issues",
                value: stats.totalIssueCount.formatted(),
                caption: "Issue contributions",
                accessibilityIdentifier: "stats.github.profile.issues"
            )

            gitHubSummaryCard(
                icon: "shippingbox.fill",
                accent: .teal,
                title: "Repos",
                value: stats.contributedRepositoryCount.formatted(),
                caption: "Repos with commits",
                accessibilityIdentifier: "stats.github.profile.repositories"
            )
        }

        if selectedRange != .today {
            gitHubChart(
                points: stats.contributionPoints,
                averageCount: stats.averageContributionCount,
                busiestDay: stats.busiestContributionDay,
                yAxisLabel: "Contributions",
                averageLabel: "Average"
            )

            HStack(spacing: 10) {
                bottomInsightPill(icon: "calendar", text: selectedRange.periodDescription)

                if let busiestContributionDay = stats.busiestContributionDay {
                    bottomInsightPill(icon: "sparkles", text: "Best day: \(StatsGitHubChartPresentation.bestDayCaption(for: busiestContributionDay))")
                } else {
                    bottomInsightPill(icon: "arrow.trianglehead.2.clockwise.rotate.90", text: "No contributions in this range")
                }

                if stats.restrictedContributionCount > 0 {
                    bottomInsightPill(icon: "lock.fill", text: "Private: \(stats.restrictedContributionCount.formatted()) hidden")
                }
            }
        }
    }

    private func cardsGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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

    private func gitHubSummaryCard(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        caption: String,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(colorScheme == .dark ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(surfaceGradient)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(accent.opacity(colorScheme == .dark ? 0.16 : 0.12))
                        .frame(width: 110, height: 110)
                        .blur(radius: 16)
                        .offset(x: 28, y: -32)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(value). \(caption)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func gitHubChart(
        points: [DoneChartPoint],
        averageCount: Double,
        busiestDay: DoneChartPoint?,
        yAxisLabel: String,
        averageLabel: String
    ) -> some View {
        StatsGitHubChartView(
            points: points,
            averageCount: averageCount,
            busiestDay: busiestDay,
            yAxisLabel: yAxisLabel,
            averageLabel: averageLabel,
            selectedRange: selectedRange,
            colorScheme: colorScheme,
            calendar: calendar,
            yearMinWidth: 2_600
        )
    }

    private func bottomInsightPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(colorScheme == .dark ? 0.14 : 0.04), in: Capsule(style: .continuous))
    }

    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.08), Color.white.opacity(0.04)]
                : [Color.white.opacity(0.98), Color.white.opacity(0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

}
