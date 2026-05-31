import Charts
import SwiftUI

struct StatsFocusWorkChartSection: View {
    let points: [FocusWorkChartPoint]
    let selectedRange: DoneChartRange
    let chartPresentation: StatsChartPresentation
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Focus vs completed work",
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: "Best paired",
                    value: strongestPairedDay.map { "\($0.doneCount) done" } ?? "0",
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            if activePoints.isEmpty {
                StatsEmptyChartStateView(
                    systemImage: "chart.dots.scatter",
                    message: "Complete tasks and finish focus sessions to compare focus time with completed work.",
                    colorScheme: colorScheme
                )
            } else {
                StatsHorizontalChartContainer(chartPresentation: chartPresentation, minHeight: 260) {
                    Chart {
                        ForEach(activePoints) { point in
                            let isHighlighted = point.date == strongestPairedDay?.date

                            PointMark(
                                x: .value("Focus minutes", point.focusMinutes),
                                y: .value("Done", Double(point.doneCount))
                            )
                            .symbolSize(isHighlighted ? 128 : symbolSize(for: point))
                            .foregroundStyle(by: .value("Day type", categoryTitle(for: point)))
                            .opacity(point.hasFocusAndDone ? 1 : 0.72)
                            .accessibilityLabel(point.date.formatted(.dateTime.month(.abbreviated).day()))
                            .accessibilityValue("\(point.doneCount) done, \(chartPresentation.focusDurationText(point.focusSeconds)) focused")
                        }

                        if averageFocusMinutes > 0 {
                            RuleMark(x: .value("Average focus", averageFocusMinutes))
                                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
                                .foregroundStyle(Color.secondary.opacity(0.35))
                        }

                        if averageDoneCount > 0 {
                            RuleMark(y: .value("Average done", averageDoneCount))
                                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
                                .foregroundStyle(Color.secondary.opacity(0.35))
                        }
                    }
                    .chartXScale(domain: 0...focusUpperBound)
                    .chartYScale(domain: 0...doneUpperBound)
                    .chartForegroundStyleScale([
                        "Focus + done": StatsFocusWorkChartPalette.paired(colorScheme: colorScheme),
                        "Focus only": StatsFocusWorkChartPalette.focusOnly(colorScheme: colorScheme),
                        "Done only": StatsFocusWorkChartPalette.doneOnly(colorScheme: colorScheme)
                    ])
                    .chartLegend(position: .bottom, alignment: .leading)
                    .chartXAxis {
                        AxisMarks(position: .bottom) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                                .foregroundStyle(Color.secondary.opacity(0.12))
                            AxisTick()
                            AxisValueLabel {
                                if let minutes = value.as(Double.self) {
                                    Text("\(Int(minutes.rounded()))m")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel {
                                if let count = value.as(Double.self) {
                                    Text(Int(count.rounded()).formatted())
                                }
                            }
                        }
                    }
                    .chartXAxisLabel("Focus minutes")
                    .chartYAxisLabel("Done")
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

    private var activePoints: [FocusWorkChartPoint] {
        points.filter(\.hasActivity)
    }

    private var strongestPairedDay: FocusWorkChartPoint? {
        FocusWorkStats.strongestPairedDay(in: points)
    }

    private var pairedDayCount: Int {
        activePoints.filter(\.hasFocusAndDone).count
    }

    private var subtitle: String {
        if activePoints.isEmpty {
            return "Each dot will compare one day of focus time with completed work."
        }
        if pairedDayCount == 0 {
            return "\(activePoints.count) days had focus time or completed work, but none had both yet."
        }
        return "\(pairedDayCount) \(pairedDayCount == 1 ? "day" : "days") paired focus time with completed work."
    }

    private var averageFocusMinutes: Double {
        guard !points.isEmpty else { return 0 }
        return points.reduce(0) { $0 + $1.focusMinutes } / Double(points.count)
    }

    private var averageDoneCount: Double {
        guard !points.isEmpty else { return 0 }
        return Double(points.reduce(0) { $0 + $1.doneCount }) / Double(points.count)
    }

    private var focusUpperBound: Double {
        max(10, ceil((activePoints.map(\.focusMinutes).max() ?? 0) + 5))
    }

    private var doneUpperBound: Double {
        Double(max((activePoints.map(\.doneCount).max() ?? 0) + 1, 1))
    }

    private var insights: [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar",
                text: StatsChartInsightBuilder.userActivityPeriodDescription(
                    selectedRange: selectedRange,
                    chartPoints: points.map { DoneChartPoint(date: $0.date, count: $0.doneCount) }
                )
            ),
            strongestPairedDay.map {
                StatsChartInsight(
                    systemImage: "scope",
                    text: "Best paired: \($0.doneCount) done with \(chartPresentation.focusDurationText($0.focusSeconds)) focus on \(chartPresentation.bestDayCaption(for: DoneChartPoint(date: $0.date, count: $0.doneCount)))"
                )
            } ?? StatsChartInsight(
                systemImage: "point.3.connected.trianglepath.dotted",
                text: "Waiting for a day with both focus time and completed work"
            )
        ]
    }

    private func symbolSize(for point: FocusWorkChartPoint) -> CGFloat {
        let countBoost = CGFloat(max(point.doneCount, 1)) * 12
        return min(92, 42 + countBoost)
    }

    private func categoryTitle(for point: FocusWorkChartPoint) -> String {
        if point.hasFocusAndDone {
            return "Focus + done"
        }
        if point.focusSeconds > 0 {
            return "Focus only"
        }
        return "Done only"
    }
}

private enum StatsFocusWorkChartPalette {
    static func paired(colorScheme: ColorScheme) -> Color {
        Color.green.opacity(colorScheme == .dark ? 0.82 : 0.68)
    }

    static func focusOnly(colorScheme: ColorScheme) -> Color {
        Color.teal.opacity(colorScheme == .dark ? 0.78 : 0.64)
    }

    static func doneOnly(colorScheme: ColorScheme) -> Color {
        Color.orange.opacity(colorScheme == .dark ? 0.84 : 0.7)
    }
}
