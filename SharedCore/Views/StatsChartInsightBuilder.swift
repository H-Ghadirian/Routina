import Foundation

enum StatsChartInsightBuilder {
    static func userActivityPeriodDescription(
        selectedRange: DoneChartRange,
        chartPoints: [DoneChartPoint]
    ) -> String {
        if selectedRange == .year,
           chartPoints.count < selectedRange.trailingDayCount,
           let firstDate = chartPoints.first?.date {
            return "Since \(firstDate.formatted(.dateTime.month(.abbreviated).day().year()))"
        }
        return selectedRange.periodDescription
    }

    static func completionInsights(
        metrics: StatsFeatureMetrics,
        selectedRange: DoneChartRange,
        chartPresentation: StatsChartPresentation
    ) -> [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar",
                text: userActivityPeriodDescription(
                    selectedRange: selectedRange,
                    chartPoints: metrics.chartPoints
                )
            ),
            metrics.highlightedBusiestDay.map {
                StatsChartInsight(
                    systemImage: "star.fill",
                    text: "Best: \(chartPresentation.bestDayCaption(for: $0))"
                )
            } ?? StatsChartInsight(
                systemImage: "waveform.path.ecg",
                text: "Waiting for your first completion"
            )
        ]
    }

    static func focusInsights(
        metrics: StatsFeatureMetrics,
        selectedRange: DoneChartRange,
        chartPresentation: StatsChartPresentation
    ) -> [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar",
                text: userActivityPeriodDescription(
                    selectedRange: selectedRange,
                    chartPoints: metrics.chartPoints
                )
            ),
            metrics.highlightedFocusDay.map {
                StatsChartInsight(
                    systemImage: "timer",
                    text: "Best: \(chartPresentation.focusDurationText($0.seconds)) on \(chartPresentation.xAxisLabel(for: $0.date))"
                )
            } ?? StatsChartInsight(
                systemImage: "stopwatch",
                text: "Waiting for your first focus session"
            )
        ]
    }

    static func createdTasksInsights(
        metrics: StatsFeatureMetrics,
        createdTasksPresentation: StatsCreatedTasksPresentation,
        chartPresentation: StatsChartPresentation
    ) -> [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar.badge.plus",
                text: createdTasksPresentation.createdInPeriodInsight(totalCount: metrics.createdTotalCount)
            ),
            metrics.highlightedCreatedDay.map {
                StatsChartInsight(
                    systemImage: "star.fill",
                    text: "Most created: \(chartPresentation.bestDayCaption(for: $0))"
                )
            } ?? StatsChartInsight(
                systemImage: "plus.circle",
                text: createdTasksPresentation.waitingInsight
            )
        ]
    }
}
