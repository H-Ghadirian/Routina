import SwiftUI

enum StatsSummaryCardItemBuilder {
    static func items(
        metrics: StatsFeatureMetrics,
        selectedRange: DoneChartRange,
        chartPresentation: StatsChartPresentation,
        taskTypeFilter: StatsTaskTypeFilter,
        filteredTaskCount: Int,
        showsActiveAccessory: Bool = false
    ) -> [StatsSummaryCardItem] {
        var items: [StatsSummaryCardItem] = []
        let activeArchivePresentation = StatsActiveArchiveSummaryPresentation(
            taskTypeFilter: taskTypeFilter,
            filteredTaskCount: filteredTaskCount,
            activeItemCount: metrics.activeRoutineCount,
            archivedItemCount: metrics.archivedRoutineCount
        )

        if selectedRange != .today {
            items.append(
                StatsSummaryCardItem(
                    icon: "gauge.with.dots.needle.50percent",
                    accent: .mint,
                    title: "Daily average",
                    value: chartPresentation.averagePerDayText(for: metrics.averagePerDay),
                    caption: "Across \(metrics.chartPoints.count) days",
                    accessibilityIdentifier: "stats.summary.dailyAverage"
                )
            )
        }

        items.append(
            StatsSummaryCardItem(
                icon: "timer",
                accent: .teal,
                title: "Focus time",
                value: chartPresentation.focusDurationText(metrics.totalFocusSeconds),
                caption: "\(metrics.focusActiveDayCount) focused \(metrics.focusActiveDayCount == 1 ? "day" : "days")",
                accessibilityIdentifier: "stats.summary.focusTime"
            )
        )

        if selectedRange != .today {
            items.append(
                StatsSummaryCardItem(
                    icon: "stopwatch.fill",
                    accent: .purple,
                    title: "Focus average",
                    value: chartPresentation.focusDurationText(metrics.averageFocusSecondsPerDay),
                    caption: "Per day in this range",
                    accessibilityIdentifier: "stats.summary.focusAverage"
                )
            )

            items.append(
                StatsSummaryCardItem(
                    icon: "bolt.fill",
                    accent: .orange,
                    title: "Best day",
                    value: metrics.highlightedBusiestDay.map { "\($0.count)" } ?? "0",
                    caption: metrics.highlightedBusiestDay.map { chartPresentation.bestDayCaption(for: $0) } ?? "No peak day yet",
                    accessibilityIdentifier: "stats.summary.bestDay"
                )
            )
        }

        items.append(
            StatsSummaryCardItem(
                icon: "checkmark.seal.fill",
                accent: .blue,
                title: "Total dones",
                value: metrics.totalDoneCount.formatted(),
                caption: "All recorded completions",
                accessibilityIdentifier: "stats.summary.totalDones"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "xmark.seal.fill",
                accent: .orange,
                title: "Total cancels",
                value: metrics.totalCanceledCount.formatted(),
                caption: "Canceled todos kept in timeline",
                accessibilityIdentifier: "stats.summary.totalCancels"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "checklist.checked",
                accent: .green,
                title: activeArchivePresentation.activeTitle,
                value: metrics.activeRoutineCount.formatted(),
                caption: activeArchivePresentation.activeCaption,
                accessibilityIdentifier: "stats.summary.activeRoutines",
                showsAccessory: showsActiveAccessory
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "archivebox.fill",
                accent: .teal,
                title: activeArchivePresentation.archivedTitle,
                value: metrics.archivedRoutineCount.formatted(),
                caption: activeArchivePresentation.archivedCaption,
                accessibilityIdentifier: "stats.summary.archivedRoutines"
            )
        )

        return items
    }
}
