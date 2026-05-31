import Charts
import SwiftUI

struct StatsFocusChartSection: View {
    let subtitle: String
    let peakValue: String
    let focusChartPoints: [FocusDurationChartPoint]
    let focusWeekdayAveragePoints: [FocusWeekdayAverageChartPoint]
    let highlightedFocusDay: FocusDurationChartPoint?
    let highlightedFocusWeekdayAverage: FocusWeekdayAverageChartPoint?
    let averageFocusSecondsPerDay: TimeInterval
    let focusChartUpperBound: Double
    let focusWeekdayAverageUpperBound: Double
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

            if chartPresentation.showsFocusWeekdayAverages {
                StatsFocusWeekdayAverageChart(
                    points: focusWeekdayAveragePoints,
                    highlightedPoint: highlightedFocusWeekdayAverage,
                    upperBound: focusWeekdayAverageUpperBound,
                    chartPresentation: chartPresentation,
                    highlightBarFill: highlightBarFill,
                    surfaceGradient: surfaceGradient,
                    colorScheme: colorScheme
                )
            }

            StatsChartInsightRow(
                insights: insights,
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }
}

private struct StatsFocusWeekdayAverageChart: View {
    let points: [FocusWeekdayAverageChartPoint]
    let highlightedPoint: FocusWeekdayAverageChartPoint?
    let upperBound: Double
    let chartPresentation: StatsChartPresentation
    let highlightBarFill: LinearGradient
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Average by weekday")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                if let highlightedPoint {
                    StatsSmallHighlightBadge(
                        title: "Top avg",
                        value: chartPresentation.focusDurationText(highlightedPoint.seconds),
                        colorScheme: colorScheme,
                        surfaceGradient: surfaceGradient
                    )
                }
            }

            Chart {
                ForEach(points) { point in
                    let isHighlighted = point.weekday == highlightedPoint?.weekday

                    BarMark(
                        x: .value("Weekday", point.shortSymbol),
                        y: .value("Average minutes", point.minutes)
                    )
                    .cornerRadius(7)
                    .foregroundStyle(
                        isHighlighted
                            ? AnyShapeStyle(highlightBarFill)
                            : AnyShapeStyle(StatsChartFill.focusBar(colorScheme: colorScheme))
                    )
                    .opacity(point.seconds == 0 ? 0.35 : 1)
                    .accessibilityLabel(point.symbol)
                    .accessibilityValue(chartPresentation.focusDurationText(point.seconds))
                }
            }
            .frame(height: 170)
            .chartYScale(domain: 0...upperBound)
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
                AxisMarks { value in
                    AxisTick()
                    AxisValueLabel {
                        if let weekday = value.as(String.self) {
                            Text(weekday)
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
        .padding(.top, 2)
    }
}
