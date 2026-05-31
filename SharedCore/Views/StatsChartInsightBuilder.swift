import Foundation

enum StatsChartInsightBuilder {
    static func userActivityPeriodDescription(
        selectedRange: DoneChartRange,
        chartPoints: [DoneChartPoint]
    ) -> String {
        periodDescription(
            selectedRange: selectedRange,
            pointCount: chartPoints.count,
            firstDate: chartPoints.first?.date
        )
    }

    static func focusActivityPeriodDescription(
        selectedRange: DoneChartRange,
        chartPoints: [FocusDurationChartPoint]
    ) -> String {
        periodDescription(
            selectedRange: selectedRange,
            pointCount: chartPoints.count,
            firstDate: chartPoints.first?.date
        )
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
                text: "Waiting for your first timeline entry"
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
                text: focusActivityPeriodDescription(
                    selectedRange: selectedRange,
                    chartPoints: metrics.focusChartPoints
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

    private static func periodDescription(
        selectedRange: DoneChartRange,
        pointCount: Int,
        firstDate: Date?
    ) -> String {
        if selectedRange == .year,
           pointCount < selectedRange.trailingDayCount,
           let firstDate {
            return "Since \(firstDate.formatted(.dateTime.month(.abbreviated).day().year()))"
        }
        return selectedRange.periodDescription
    }
}
