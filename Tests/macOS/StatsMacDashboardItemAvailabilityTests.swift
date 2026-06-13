import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct StatsMacDashboardItemAvailabilityTests {
    @Test
    func recentWins_requiresBetaExperiment() {
        #expect(!StatsMacDashboardItem.recentWins.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: true
        ))
        #expect(StatsMacDashboardItem.recentWins.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: false
        ))
    }

    @Test
    func achievements_requiresBetaExperiment() {
        #expect(!StatsMacDashboardItem.focusAchievements.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: false
        ))
        #expect(StatsMacDashboardItem.focusAchievements.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: true
        ))
    }

    @Test
    func gitHubStillRequiresGitFeatures() {
        #expect(!StatsMacDashboardItem.gitHub.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(StatsMacDashboardItem.gitHub.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: false
        ))
    }

    @Test
    func goalProgress_requiresGoalsBetaExperiment() {
        #expect(!StatsMacDashboardItem.goals.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: false,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(!StatsMacDashboardItem.goalProgress.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: false,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(StatsMacDashboardItem.goalProgress.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: false
        ))
    }

    @Test
    func emotionTrend_requiresEventEmotionBetaExperiment() {
        #expect(!StatsMacDashboardItem.events.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: false,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(!StatsMacDashboardItem.emotions.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: false,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(!StatsMacDashboardItem.emotionTrend.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: true,
            isGoalsTabEnabled: true,
            areMacEventEmotionActionsEnabled: false,
            isStatsWinsEnabled: true,
            isStatsAchievementsEnabled: true
        ))
        #expect(StatsMacDashboardItem.emotionTrend.isAvailable(
            selectedRange: .week,
            isGitFeaturesEnabled: false,
            isGoalsTabEnabled: false,
            areMacEventEmotionActionsEnabled: true,
            isStatsWinsEnabled: false,
            isStatsAchievementsEnabled: false
        ))
    }
}
