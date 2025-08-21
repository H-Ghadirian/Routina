import Charts
import SwiftUI

struct StatsFocusChartSection: View {
    let subtitle: String
    let peakValue: String
    let focusChartPoints: [FocusDurationChartPoint]
    let highlightedFocusDay: FocusDurationChartPoint?
    let averageFocusSecondsPerDay: TimeInterval
    let focusChartUpperBound: Double
    let xAxisDates: [Date]
    let chartPresentation: StatsChartPresentation
    let highlightBarFill: LinearGradient
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme
    let insights: [StatsChartInsight]

    var body: some View {
        let focusBarXAxisDates = chartPresentation.focusBarXAxisDates(from: focusChartPoints)
        let focusBarXAxisDateSet = Set(focusBarXAxisDates)

        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Focus time per day",
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: "Peak",
                    value: peakValue,
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            StatsHorizontalChartContainer(chartPresentation: chartPresentation, minHeight: 240) {
                Chart {
                    ForEach(focusChartPoints) { point in
                        let isHighlighted = point.date == highlightedFocusDay?.date

                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Minutes", point.minutes)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isHighlighted
                                ? AnyShapeStyle(highlightBarFill)
                                : AnyShapeStyle(StatsChartFill.focusBar(colorScheme: colorScheme))
                        )
                        .opacity(point.seconds == 0 ? 0.35 : 1)
                    }

                    if averageFocusSecondsPerDay > 0 {
                        RuleMark(y: .value("Average", averageFocusSecondsPerDay / 60))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .annotation(position: .topLeading, alignment: .leading) {
                                Text("Avg \(chartPresentation.focusDurationText(averageFocusSecondsPerDay))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(surfaceGradient, in: Capsule(style: .continuous))
                            }
                    }
                }
                .chartYScale(domain: 0...focusChartUpperBound)
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
                    AxisMarks(values: xAxisDates) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self),
                               !focusBarXAxisDateSet.contains(date) {
                                Text(chartPresentation.xAxisLabel(for: date))
                            }
                        }
                    }
                    AxisMarks(values: focusBarXAxisDates) { value in
                        AxisTick()
                            .foregroundStyle(Color.secondary.opacity(0.35))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(chartPresentation.focusBarXAxisLabel(for: date))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary.opacity(0.75))
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
