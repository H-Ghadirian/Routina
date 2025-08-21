import Charts
import SwiftUI

struct StatsCompletionChartSection: View {
    let subtitle: String
    let peakValue: String
    let chartPoints: [DoneChartPoint]
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
                title: "Completions per day",
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
                    ForEach(chartPoints) { point in
                        let isHighlighted = point.date == highlightedPoint?.date

                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Completions", point.count)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isHighlighted
                                ? AnyShapeStyle(highlightBarFill)
                                : AnyShapeStyle(baseBarFill)
                        )
                        .opacity(point.count == 0 ? 0.35 : 1)
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
                            y: .value("Completions", highlightedPoint.count)
                        )
                        .symbolSize(highlightSymbolSize)
                        .foregroundStyle(Color.white)
                    }
                }
                .chartYScale(domain: 0...chartUpperBound)
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
                                Text(chartPresentation.xAxisLabel(for: date))
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
}
