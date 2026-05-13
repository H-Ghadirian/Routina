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
                title: "Done",
                value: metrics.totalDoneCount.formatted(),
                caption: "Recorded completions",
                accessibilityIdentifier: "stats.summary.totalDones"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "xmark.seal.fill",
                accent: .orange,
                title: "Canceled",
                value: metrics.totalCanceledCount.formatted(),
                caption: "Resolved cancellations",
                accessibilityIdentifier: "stats.summary.totalCancels"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "exclamationmark.triangle.fill",
                accent: .yellow,
                title: "Missed",
                value: metrics.totalMissedCount.formatted(),
                caption: "Confirmed missed occurrences",
                accessibilityIdentifier: "stats.summary.totalMissed"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "arrow.clockwise",
                accent: .indigo,
                title: "Routines",
                value: metrics.routineCount.formatted(),
                caption: "Total matching routines",
                accessibilityIdentifier: "stats.summary.routineCount"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "checkmark.circle",
                accent: .cyan,
                title: "Todos",
                value: metrics.openTodoCount.formatted(),
                caption: "Open matching todos",
                accessibilityIdentifier: "stats.summary.todoCount"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "checklist",
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
