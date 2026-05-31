import Charts
import SwiftUI

struct StatsEstimateActualChartSection: View {
    let points: [EstimateActualChartPoint]
    let selectedRange: DoneChartRange
    let chartPresentation: StatsChartPresentation
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Estimated vs actual time",
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: "Delta",
                    value: deltaText(totalDeltaMinutes),
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            if activePoints.isEmpty {
                StatsEmptyChartStateView(
                    systemImage: "timer",
                    message: "Completed work with estimates and logged actual time will appear here.",
                    colorScheme: colorScheme
                )
            } else {
                StatsHorizontalChartContainer(chartPresentation: chartPresentation, minHeight: 250) {
                    Chart {
                        ForEach(points) { point in
                            BarMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Minutes", Double(point.estimatedMinutes))
                            )
                            .cornerRadius(6)
                            .foregroundStyle(by: .value("Time type", "Estimated"))
                            .position(by: .value("Time type", "Estimated"))
                            .opacity(point.hasTrackedTime ? 0.92 : 0.25)

                            BarMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Minutes", Double(point.actualMinutes))
                            )
                            .cornerRadius(6)
                            .foregroundStyle(by: .value("Time type", "Actual"))
                            .position(by: .value("Time type", "Actual"))
                            .opacity(point.hasTrackedTime ? 1 : 0.25)
                            .accessibilityLabel(point.date.formatted(.dateTime.month(.abbreviated).day()))
                            .accessibilityValue(accessibilityValue(for: point))
                        }
                    }
                    .chartYScale(domain: 0...upperBound)
                    .chartForegroundStyleScale([
                        "Estimated": StatsEstimateActualChartPalette.estimated(colorScheme: colorScheme),
                        "Actual": StatsEstimateActualChartPalette.actual(colorScheme: colorScheme)
                    ])
                    .chartLegend(position: .bottom, alignment: .leading)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel {
                                if let minutes = value.as(Double.self) {
                                    Text("\(Int(minutes.rounded()))m")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: chartPresentation.dailyBarXAxisDates(from: doneAxisPoints)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                                .foregroundStyle(Color.secondary.opacity(0.12))
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(chartPresentation.dailyBarXAxisLabel(for: date))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxisLabel("Minutes")
                    .chartPlotStyle { plotArea in
                        plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                    }
                }
            }

            StatsChartInsightRow(
                insights: insights,
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }

    private var activePoints: [EstimateActualChartPoint] {
        points.filter(\.hasTrackedTime)
    }

    private var trackedCompletionCount: Int {
        points.reduce(0) { $0 + $1.trackedCompletionCount }
    }

    private var totalEstimatedMinutes: Int {
        EstimateActualStats.totalEstimatedMinutes(in: points)
    }

    private var totalActualMinutes: Int {
        EstimateActualStats.totalActualMinutes(in: points)
    }

    private var totalDeltaMinutes: Int {
        totalActualMinutes - totalEstimatedMinutes
    }

    private var largestVarianceDay: EstimateActualChartPoint? {
        EstimateActualStats.largestVarianceDay(in: points)
    }

    private var subtitle: String {
        if trackedCompletionCount == 0 {
            return "Compare planned time with logged time for completed work."
        }

        return "\(trackedCompletionCount) tracked \(trackedCompletionCount == 1 ? "completion" : "completions") with estimates and actual time."
    }

    private var upperBound: Double {
        let maximum = activePoints
            .flatMap { [Double($0.estimatedMinutes), Double($0.actualMinutes)] }
            .max() ?? 0
        return max(10, ceil(maximum) + 5)
    }

    private var doneAxisPoints: [DoneChartPoint] {
        points.map { DoneChartPoint(date: $0.date, count: $0.trackedCompletionCount) }
    }

    private var insights: [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar",
                text: StatsChartInsightBuilder.userActivityPeriodDescription(
                    selectedRange: selectedRange,
                    chartPoints: doneAxisPoints
                )
            ),
            largestVarianceDay.map {
                StatsChartInsight(
                    systemImage: $0.deltaMinutes > 0 ? "arrow.up.forward" : "arrow.down.forward",
                    text: "\(deltaText($0.deltaMinutes)) on \(chartPresentation.bestDayCaption(for: DoneChartPoint(date: $0.date, count: $0.trackedCompletionCount)))"
                )
            } ?? StatsChartInsight(
                systemImage: "timer",
                text: "Waiting for estimated work with logged actual time"
            )
        ]
    }

    private func minutesText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0m" }
        return FocusSessionFormatting.compactDurationText(seconds: TimeInterval(minutes * 60))
    }

    private func deltaText(_ minutes: Int) -> String {
        if minutes > 0 {
            return "Over \(minutesText(minutes))"
        }
        if minutes < 0 {
            return "Under \(minutesText(abs(minutes)))"
        }
        return "On plan"
    }

    private func accessibilityValue(for point: EstimateActualChartPoint) -> String {
        "\(minutesText(point.estimatedMinutes)) estimated, \(minutesText(point.actualMinutes)) actual"
    }
}

private enum StatsEstimateActualChartPalette {
    static func estimated(colorScheme: ColorScheme) -> Color {
        Color.indigo.opacity(colorScheme == .dark ? 0.78 : 0.66)
    }

    static func actual(colorScheme: ColorScheme) -> Color {
        Color.green.opacity(colorScheme == .dark ? 0.82 : 0.68)
    }
}
