import SwiftUI

extension StatsView {
    func gitHubSection(snapshot: DashboardSnapshot) -> some View {
        StatsMacGitHubSection(
            connection: snapshot.gitHubConnection,
            stats: snapshot.gitHubStats,
            errorMessage: snapshot.gitHubStatsErrorMessage,
            isLoading: snapshot.isGitHubStatsLoading,
            selectedRange: snapshot.selectedRange,
            horizontalSizeClass: horizontalSizeClass,
            colorScheme: colorScheme,
            calendar: calendar,
            onRefresh: { store.send(.gitHubStatsRefreshRequested) }
        )
    }

    func createdTasksChartSection(snapshot: DashboardSnapshot) -> some View {
        StatsCreatedTasksChartSection(
            metrics: snapshot.metrics,
            selectedRange: snapshot.selectedRange,
            selectedTaskTypeFilter: snapshot.selectedCreatedChartTaskTypeFilter,
            chartPresentation: snapshot.chartPresentation,
            createdTasksPresentation: snapshot.createdTasksPresentation,
            createdBarFill: createdBarFill,
            highlightBarFill: highlightBarFill,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme,
            onSelectTaskTypeFilter: { store.send(.createdChartTaskTypeFilterChanged($0)) }
        )
    }

    func chartSection(snapshot: DashboardSnapshot) -> some View {
        let metrics = snapshot.metrics

        return StatsCompletionChartSection(
            subtitle: snapshot.chartPresentation.chartSectionSubtitle(
                totalCount: metrics.totalCount,
                averagePerDay: metrics.averagePerDay,
                dayCount: metrics.chartPoints.count
            ),
            peakValue: metrics.highlightedBusiestDay.map { "\($0.count)" } ?? "0",
            chartPoints: metrics.chartPoints,
            outcomePoints: metrics.outcomeMixChartPoints,
            highlightedPoint: metrics.highlightedBusiestDay,
            averagePerDay: metrics.averagePerDay,
            chartUpperBound: metrics.chartUpperBound,
            xAxisDates: snapshot.chartPresentation.dailyBarXAxisDates(from: metrics.chartPoints),
            highlightSymbolSize: snapshot.selectedRange == .year ? 46 : 64,
            chartPresentation: snapshot.chartPresentation,
            baseBarFill: baseBarFill,
            highlightBarFill: highlightBarFill,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme,
            insights: StatsChartInsightBuilder.completionInsights(
                metrics: metrics,
                selectedRange: snapshot.selectedRange,
                chartPresentation: snapshot.chartPresentation
            )
        )
    }

    func hourlyActivitySection(snapshot: DashboardSnapshot) -> some View {
        StatsHourlyActivitySection(
            points: snapshot.metrics.hourlyActivityChartPoints,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    func focusChartSection(snapshot: DashboardSnapshot) -> some View {
        let metrics = snapshot.metrics

        return StatsFocusChartSection(
            subtitle: snapshot.chartPresentation.focusChartSectionSubtitle(
                totalFocusSeconds: metrics.totalFocusSeconds,
                activeDayCount: metrics.focusActiveDayCount
            ),
            peakValue: metrics.highlightedFocusDay.map { snapshot.chartPresentation.focusDurationText($0.seconds) } ?? "0m",
            focusChartPoints: metrics.focusChartPoints,
            focusWeekdayAveragePoints: metrics.focusWeekdayAveragePoints,
            highlightedFocusDay: metrics.highlightedFocusDay,
            highlightedFocusWeekdayAverage: metrics.highlightedFocusWeekdayAverage,
            averageFocusSecondsPerDay: metrics.averageFocusSecondsPerDay,
            focusChartUpperBound: metrics.focusChartUpperBound,
            focusWeekdayAverageUpperBound: metrics.focusWeekdayAverageUpperBound,
            chartPresentation: snapshot.chartPresentation,
            highlightBarFill: highlightBarFill,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme,
            insights: StatsChartInsightBuilder.focusInsights(
                metrics: metrics,
                selectedRange: snapshot.selectedRange,
                chartPresentation: snapshot.chartPresentation
            )
        )
    }

    func focus2048Section(snapshot: DashboardSnapshot) -> some View {
        StatsFocus2048Section(
            totalFocusSeconds: snapshot.metrics.totalFocusSeconds,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme,
            showsSupplementaryDetails: true
        )
    }

    func achievementsSection() -> some View {
        let snapshot = visibleAchievementSnapshot
        return StatsAchievementsSection(
            achievements: snapshot.achievements,
            earnedAchievementIDsByPeriod: snapshot.earnedAchievementIDsByPeriod,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    func recentWinsSection() -> some View {
        let snapshot = visibleAchievementSnapshot
        return StatsRecentWinsSection(
            celebrations: snapshot.celebrations,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    func tagUsageSection(snapshot: DashboardSnapshot) -> some View {
        let metrics = snapshot.metrics

        return StatsTagUsageSection(
            points: metrics.tagUsagePoints,
            subtitle: snapshot.chartPresentation.tagUsageSectionSubtitle(
                points: metrics.tagUsagePoints,
                periodDescription: snapshot.selectedRange.periodDescription
            ),
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    func focusWorkChartSection(snapshot: DashboardSnapshot) -> some View {
        StatsFocusWorkChartSection(
            points: snapshot.metrics.focusWorkChartPoints,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    func estimateActualChartSection(snapshot: DashboardSnapshot) -> some View {
        StatsEstimateActualChartSection(
            points: snapshot.metrics.estimateActualChartPoints,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    func goalProgressSection(snapshot: DashboardSnapshot) -> some View {
        StatsGoalProgressSection(
            points: snapshot.metrics.goalProgressChartPoints,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    func emotionTrendSection(snapshot: DashboardSnapshot) -> some View {
        StatsEmotionTrendSection(
            points: snapshot.metrics.emotionTrendChartPoints,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }
}
