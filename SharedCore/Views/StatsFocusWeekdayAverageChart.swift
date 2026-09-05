import Charts
import SwiftUI

struct StatsFocusWeekdayAverageChart: View {
    let points: [FocusWeekdayAverageChartPoint]
    let highlightedPoint: FocusWeekdayAverageChartPoint?
    let upperBound: Double
    let chartPresentation: StatsChartPresentation
    let highlightBarFill: LinearGradient
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    var body: some View {
        let averageAxisUpperBound = StatsChartTimeAxis.upperBound(for: upperBound)

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
            .chartYScale(domain: 0...averageAxisUpperBound)
            .chartYAxis {
                AxisMarks(
                    position: .leading,
                    values: StatsChartTimeAxis.values(upperBound: averageAxisUpperBound)
                ) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text(StatsChartTimeAxis.label(for: minutes))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
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
            .chartYAxisLabel("Avg focus")
        }
        .padding(.top, 2)
    }
}
