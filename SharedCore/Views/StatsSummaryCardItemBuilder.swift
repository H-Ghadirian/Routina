import SwiftUI

enum StatsSummaryCardItemBuilder {
    static func items(
        metrics: StatsFeatureMetrics,
        selectedRange: DoneChartRange,
        chartPresentation: StatsChartPresentation,
        taskTypeFilter: StatsTaskTypeFilter,
        filteredTaskCount: Int,
        healthSummary: HealthStatsSummary? = nil,
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

        if let healthSummary {
            items.append(contentsOf: healthItems(
                summary: healthSummary,
                selectedRange: selectedRange
            ))
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
                icon: "bed.double.fill",
                accent: .indigo,
                title: "Sleep time",
                value: SleepSessionFormatting.durationText(seconds: metrics.totalSleepSeconds),
                caption: sleepTimeCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.sleepTime"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "moon.fill",
                accent: .blue,
                title: "Sleep sessions",
                value: metrics.sleepSessionCount.formatted(),
                caption: sleepSessionCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.sleepSessions"
            )
        )

        items.append(
            StatsSummaryCardItem(
                icon: "lock.shield.fill",
                accent: .mint,
                title: "Away time",
                value: chartPresentation.focusDurationText(metrics.totalAwaySeconds),
                caption: awayCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.awayTime"
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

    private static func healthItems(
        summary: HealthStatsSummary,
        selectedRange: DoneChartRange
    ) -> [StatsSummaryCardItem] {
        [
            StatsSummaryCardItem(
                icon: "figure.walk",
                accent: .green,
                title: "Steps",
                value: wholeNumberText(summary.steps),
                caption: healthCaption(for: selectedRange),
                accessibilityIdentifier: "stats.summary.health.steps"
            ),
            StatsSummaryCardItem(
                icon: "flame.fill",
                accent: .orange,
                title: "Active calories",
                value: "\(wholeNumberText(summary.activeEnergyKilocalories)) kcal",
                caption: "Burned in \(selectedRange.periodDescription.lowercased())",
                accessibilityIdentifier: "stats.summary.health.activeCalories"
            ),
            StatsSummaryCardItem(
                icon: "map.fill",
                accent: .mint,
                title: "Distance",
                value: distanceText(summary.walkingRunningDistanceMeters),
                caption: "Walking and running",
                accessibilityIdentifier: "stats.summary.health.distance"
            ),
            StatsSummaryCardItem(
                icon: "figure.run",
                accent: .cyan,
                title: "Exercise",
                value: "\(wholeNumberText(summary.exerciseMinutes)) min",
                caption: "Exercise minutes",
                accessibilityIdentifier: "stats.summary.health.exercise"
            )
        ]
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

    private static func sleepTimeCaption(metrics: StatsFeatureMetrics) -> String {
        guard metrics.sleepSessionCount > 0 else {
            return "No sleep sessions in range"
        }

        return "\(metrics.sleepActiveDayCount) sleep \(metrics.sleepActiveDayCount == 1 ? "day" : "days")"
    }

    private static func sleepSessionCaption(metrics: StatsFeatureMetrics) -> String {
        guard metrics.sleepSessionCount > 0 else {
            return "No sleep sessions in range"
        }

        let activeCount = metrics.sleepSessionCount - metrics.completedSleepSessionCount
        if activeCount > 0 {
            return "\(metrics.completedSleepSessionCount) completed, \(activeCount) active"
        }

        return "\(metrics.completedSleepSessionCount) completed"
    }

    private static func awayCaption(metrics: StatsFeatureMetrics) -> String {
        guard metrics.awaySessionCount > 0 else {
            return "No away sessions in range"
        }

        if metrics.endedEarlyAwaySessionCount > 0 {
            return "\(metrics.awaySessionCount) sessions, \(metrics.endedEarlyAwaySessionCount) ended early"
        }

        return "\(metrics.completedAwaySessionCount) completed across \(metrics.awayActiveDayCount) \(metrics.awayActiveDayCount == 1 ? "day" : "days")"
    }

    private static func goalCaption(metrics: StatsFeatureMetrics) -> String {
        "\(metrics.goalsCreatedCount) new, \(metrics.archivedGoalCount) archived"
    }

    private static func healthCaption(for selectedRange: DoneChartRange) -> String {
        "From Apple Health, \(selectedRange.periodDescription.lowercased())"
    }

    private static func wholeNumberText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private static func distanceText(_ meters: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = meters >= 1000 ? 1 : 0
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }
}
