import Testing
@testable @preconcurrency import Routina

struct StatsDashboardItemAvailabilityTests {
    @Test
    func unassignedFocus_isRetiredFromDashboardAvailability() {
        #expect(!StatsDashboardItem.unassignedFocus.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
    }

    @Test
    func recentWins_requiresBetaExperiment() {
        #expect(!StatsDashboardItem.recentWins.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: true
        ))
        #expect(StatsDashboardItem.recentWins.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: false
        ))
    }

    @Test
    func achievements_requiresBetaExperiment() {
        #expect(!StatsDashboardItem.focusAchievements.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: false
        ))
        #expect(StatsDashboardItem.focusAchievements.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: true
        ))
    }

    @Test
    func gitHubStillRequiresGitFeatures() {
        #expect(!StatsDashboardItem.gitHub.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(StatsDashboardItem.gitHub.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: false
        ))
    }

    @Test
    func goalReports_requireGoalsBetaExperiment() {
        #expect(!StatsDashboardItem.goals.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: false,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(!StatsDashboardItem.goalProgress.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: false,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(StatsDashboardItem.goals.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: false
        ))
        #expect(StatsDashboardItem.goalProgress.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: false
        ))
    }

    @Test
    func trackingReports_requireTrackingBackingMetrics() {
        let emptyMetrics = StatsFeatureMetrics()
        #expect(!StatsDashboardItem.trackingCount.isReportable(
            metrics: emptyMetrics,
            healthSummary: nil
        ))
        #expect(!StatsDashboardItem.trackingTime.isReportable(
            metrics: emptyMetrics,
            healthSummary: nil
        ))

        let countMetrics = StatsFeatureMetrics(trackingEntryCount: 2)
        #expect(StatsDashboardItem.trackingCount.isReportable(
            metrics: countMetrics,
            healthSummary: nil
        ))
        #expect(!StatsDashboardItem.trackingTime.isReportable(
            metrics: countMetrics,
            healthSummary: nil
        ))

        let timeMetrics = StatsFeatureMetrics(totalTrackingActualMinutes: 45)
        #expect(StatsDashboardItem.trackingTime.isReportable(
            metrics: timeMetrics,
            healthSummary: nil
        ))
    }

    @Test
    func trackingSummaryIdentifiers_mapToDashboardItems() {
        #expect(StatsDashboardItem(summaryAccessibilityIdentifier: "stats.summary.trackingCount") == .trackingCount)
        #expect(StatsDashboardItem(summaryAccessibilityIdentifier: "stats.summary.trackingTime") == .trackingTime)
    }
}
