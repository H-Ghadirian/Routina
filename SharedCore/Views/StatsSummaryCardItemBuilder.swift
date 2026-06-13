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

        return items.filter {
            StatsDashboardReportAvailability.isReportable(
                summaryAccessibilityIdentifier: $0.accessibilityIdentifier,
                metrics: metrics,
                healthSummary: healthSummary
            )
        }
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

enum StatsDashboardReportAvailability {
    static func isReportable(
        itemID: String,
        metrics: StatsFeatureMetrics,
        healthSummary: HealthStatsSummary? = nil
    ) -> Bool {
        switch itemID {
        case "hero",
             "dailyAverage",
             "bestDay",
             "totalDones",
             "totalCancels",
             "totalMissed",
             "completionChart":
            return metrics.totalCount > 0
        case "healthSteps":
            return (healthSummary?.steps ?? 0) > 0
        case "healthActiveCalories":
            return (healthSummary?.activeEnergyKilocalories ?? 0) > 0
        case "healthDistance":
            return (healthSummary?.walkingRunningDistanceMeters ?? 0) > 0
        case "healthExercise":
            return (healthSummary?.exerciseMinutes ?? 0) > 0
        case "focusTime",
             "focusAverage",
             "focusChart",
             "focus2048":
            return metrics.totalFocusSeconds > 0
        case "sleepTime":
            return metrics.totalSleepSeconds > 0
        case "sleepSessions":
            return metrics.sleepSessionCount > 0
        case "awayTime":
            return metrics.totalAwaySeconds > 0
        case "emotions",
             "emotionTrend":
            return metrics.emotionLogCount > 0
        case "notes":
            return metrics.noteCount > 0
        case "events":
            return metrics.eventCount > 0
        case "goals":
            return metrics.activeGoalCount > 0
                || metrics.archivedGoalCount > 0
                || metrics.goalsCreatedCount > 0
        case "goalProgress":
            return !metrics.goalProgressChartPoints.isEmpty
        case "routineCount":
            return metrics.routineCount > 0
        case "todoCount":
            return metrics.openTodoCount > 0
        case "activeItems":
            return metrics.activeRoutineCount > 0
        case "archivedItems":
            return metrics.archivedRoutineCount > 0
        case "createdTasksChart":
            return metrics.createdTotalCount > 0
        case "hourlyActivity":
            return metrics.hourlyActivityChartPoints.contains(where: \.hasActivity)
        case "tagUsage":
            return metrics.tagUsagePoints.contains {
                $0.completionCount > 0 || $0.linkedRoutineCount > 0 || $0.linkedTodoCount > 0
            }
        case "focusWorkChart":
            return metrics.focusWorkChartPoints.contains(where: \.hasActivity)
        case "estimateActual":
            return metrics.estimateActualChartPoints.contains(where: \.hasTrackedTime)
        case "recentWins":
            return hasAnyCurrentPeriodActivity(metrics)
        case "focusAchievements":
            return hasAnyCurrentPeriodActivity(metrics)
        case "unassignedFocus",
             "gitHub":
            return true
        default:
            return true
        }
    }

    static func isReportable(
        summaryAccessibilityIdentifier: String,
        metrics: StatsFeatureMetrics,
        healthSummary: HealthStatsSummary? = nil
    ) -> Bool {
        switch summaryAccessibilityIdentifier {
        case "stats.summary.dailyAverage":
            return isReportable(itemID: "dailyAverage", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.health.steps":
            return isReportable(itemID: "healthSteps", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.health.activeCalories":
            return isReportable(itemID: "healthActiveCalories", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.health.distance":
            return isReportable(itemID: "healthDistance", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.health.exercise":
            return isReportable(itemID: "healthExercise", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.focusTime":
            return isReportable(itemID: "focusTime", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.sleepTime":
            return isReportable(itemID: "sleepTime", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.sleepSessions":
            return isReportable(itemID: "sleepSessions", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.awayTime":
            return isReportable(itemID: "awayTime", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.emotions":
            return isReportable(itemID: "emotions", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.notes":
            return isReportable(itemID: "notes", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.events":
            return isReportable(itemID: "events", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.goals":
            return isReportable(itemID: "goals", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.focusAverage":
            return isReportable(itemID: "focusAverage", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.bestDay":
            return isReportable(itemID: "bestDay", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.totalDones":
            return metrics.totalDoneCount > 0
        case "stats.summary.totalCancels":
            return metrics.totalCanceledCount > 0
        case "stats.summary.totalMissed":
            return metrics.totalMissedCount > 0
        case "stats.summary.routineCount":
            return isReportable(itemID: "routineCount", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.todoCount":
            return isReportable(itemID: "todoCount", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.activeRoutines":
            return isReportable(itemID: "activeItems", metrics: metrics, healthSummary: healthSummary)
        case "stats.summary.archivedRoutines":
            return isReportable(itemID: "archivedItems", metrics: metrics, healthSummary: healthSummary)
        default:
            return true
        }
    }

    private static func hasAnyCurrentPeriodActivity(_ metrics: StatsFeatureMetrics) -> Bool {
        metrics.totalCount > 0
            || metrics.createdTotalCount > 0
            || metrics.totalFocusSeconds > 0
            || metrics.totalSleepSeconds > 0
            || metrics.totalAwaySeconds > 0
            || metrics.emotionLogCount > 0
            || metrics.noteCount > 0
            || metrics.eventCount > 0
            || metrics.goalsCreatedCount > 0
    }
}
