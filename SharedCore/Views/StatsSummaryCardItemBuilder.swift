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

        items.append(
            StatsSummaryCardItem(
                icon: "heart.fill",
                accent: .pink,
                title: "Emotions",
                value: metrics.emotionLogCount.formatted(),
                caption: emotionCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.emotions"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "note.text",
                accent: .brown,
                title: "Notes",
                value: metrics.noteCount.formatted(),
                caption: noteCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.notes"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "calendar",
                accent: .teal,
                title: "Events",
                value: metrics.eventCount.formatted(),
                caption: eventCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.events"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "target",
                accent: .indigo,
                title: "Goals",
                value: metrics.activeGoalCount.formatted(),
                caption: goalCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.goals"
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

    private static func emotionCaption(metrics: StatsFeatureMetrics) -> String {
        guard metrics.emotionLogCount > 0 else {
            return "No emotion logs in range"
        }

        let intensity = metrics.averageEmotionIntensity.formatted(.number.precision(.fractionLength(1)))
        return "\(metrics.emotionActiveDayCount) logged \(metrics.emotionActiveDayCount == 1 ? "day" : "days"), avg \(intensity)/5"
    }

    private static func noteCaption(metrics: StatsFeatureMetrics) -> String {
        guard metrics.noteCount > 0 else {
            return "No notes in range"
        }

        return "\(metrics.noteWithMediaCount) with media"
    }

    private static func eventCaption(metrics: StatsFeatureMetrics) -> String {
        guard metrics.eventCount > 0 else {
            return "No events in range"
        }

        return "\(metrics.eventActiveDayCount) calendar \(metrics.eventActiveDayCount == 1 ? "day" : "days")"
    }

    private static func goalCaption(metrics: StatsFeatureMetrics) -> String {
        "\(metrics.goalsCreatedCount) new, \(metrics.archivedGoalCount) archived"
    }
}
