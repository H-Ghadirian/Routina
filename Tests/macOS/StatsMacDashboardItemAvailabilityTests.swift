import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct StatsMacDashboardItemAvailabilityTests {
    @Test
    func recentWins_requiresBetaExperiment() {
        #expect(!StatsMacDashboardItem.recentWins.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: true
        ))
        #expect(StatsMacDashboardItem.recentWins.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: false
        ))
    }

    @Test
    func achievements_requiresBetaExperiment() {
        #expect(!StatsMacDashboardItem.focusAchievements.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: false
        ))
        #expect(StatsMacDashboardItem.focusAchievements.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: true
        ))
    }

    @Test
    func gitHubStillRequiresGitFeatures() {
        #expect(!StatsMacDashboardItem.gitHub.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(StatsMacDashboardItem.gitHub.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: false
        ))
    }
}
