import Charts
import SwiftUI

struct StatsCompletionChartSection: View {
    let subtitle: String
    let peakValue: String
    let chartPoints: [DoneChartPoint]
    let outcomePoints: [OutcomeMixChartPoint]
    let highlightedPoint: DoneChartPoint?
    let averagePerDay: Double
    let chartUpperBound: Double
    let xAxisDates: [Date]
    let highlightSymbolSize: CGFloat
    let chartPresentation: StatsChartPresentation
    let baseBarFill: LinearGradient
    let highlightBarFill: LinearGradient
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme
    let insights: [StatsChartInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Timeline activity per day",
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: "Peak",
                    value: peakValue,
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            StatsHorizontalChartContainer(chartPresentation: chartPresentation, minHeight: 260) {
                Chart {
                    ForEach(outcomeSegments) { segment in
                        BarMark(
                            x: .value("Date", segment.date, unit: .day),
                            y: .value("Activity", segment.count)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(by: .value("Outcome", segment.title))
                        .accessibilityLabel("\(segment.title) on \(chartPresentation.bestDayCaption(for: DoneChartPoint(date: segment.date, count: segment.count)))")
                        .accessibilityValue(segment.count.formatted())
                    }

                    if averagePerDay > 0 {
                        RuleMark(y: .value("Average", averagePerDay))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .annotation(position: .topLeading, alignment: .leading) {
                                Text("Avg \(chartPresentation.averagePerDayText(for: averagePerDay))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        surfaceGradient,
                                        in: Capsule(style: .continuous)
                                    )
                            }
                    }

                    if let highlightedPoint {
                        PointMark(
                            x: .value("Date", highlightedPoint.date, unit: .day),
                            y: .value("Activity", highlightedPoint.count)
                        )
                        .symbolSize(highlightSymbolSize)
                        .foregroundStyle(Color.white)
                    }
                }
                .chartYScale(domain: 0...chartUpperBound)
                .chartForegroundStyleScale([
                    "Done": StatsOutcomeChartPalette.done(colorScheme: colorScheme),
                    "Missed": StatsOutcomeChartPalette.missed(colorScheme: colorScheme),
                    "Canceled": StatsOutcomeChartPalette.canceled(colorScheme: colorScheme)
                ])
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let count = value.as(Int.self) {
                                Text(count.formatted())
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xAxisDates) { value in
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
                .chartPlotStyle { plotArea in
                    plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                }
            }

            StatsChartInsightRow(
                insights: insights,
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }

    private var outcomeSegments: [StatsOutcomeChartSegment] {
        let sourcePoints = outcomePoints.isEmpty
            ? chartPoints.map {
                OutcomeMixChartPoint(
                    date: $0.date,
                    doneCount: $0.count,
                    missedCount: 0,
                    canceledCount: 0
                )
            }
            : outcomePoints

        return sourcePoints.flatMap { point in
            [
                StatsOutcomeChartSegment(date: point.date, kind: .completed, count: point.doneCount),
                StatsOutcomeChartSegment(date: point.date, kind: .missed, count: point.missedCount),
                StatsOutcomeChartSegment(date: point.date, kind: .canceled, count: point.canceledCount)
            ].filter { $0.count > 0 }
        }
    }
}

private struct StatsOutcomeChartSegment: Identifiable {
    let date: Date
    let kind: RoutineLogKind
    let count: Int

    var id: String {
        "\(date.timeIntervalSinceReferenceDate)-\(kind.rawValue)"
    }

    var title: String {
        switch kind {
        case .completed:
            return "Done"
        case .missed:
            return "Missed"
        case .canceled:
            return "Canceled"
        }
    }
}

private enum StatsOutcomeChartPalette {
    static func done(colorScheme: ColorScheme) -> Color {
        Color.green.opacity(colorScheme == .dark ? 0.82 : 0.68)
    }

    static func missed(colorScheme: ColorScheme) -> Color {
        Color.orange.opacity(colorScheme == .dark ? 0.88 : 0.74)
    }

    static func canceled(colorScheme: ColorScheme) -> Color {
        Color.secondary.opacity(colorScheme == .dark ? 0.74 : 0.58)
    }
}
