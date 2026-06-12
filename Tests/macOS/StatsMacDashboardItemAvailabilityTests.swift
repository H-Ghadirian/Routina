import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct StatsMacDashboardItemAvailabilityTests {
    @Test
    func recentWins_requiresBetaExperiment() {
        #expect(!StatsMacDashboardItem.recentWins.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isStatsWinsEnabled: false
        ))
        #expect(StatsMacDashboardItem.recentWins.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isStatsWinsEnabled: true
        ))
    }

    @Test
    func gitHubStillRequiresGitFeatures() {
        #expect(!StatsMacDashboardItem.gitHub.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isStatsWinsEnabled: true
        ))
        #expect(StatsMacDashboardItem.gitHub.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isStatsWinsEnabled: false
        ))
    }
}
