import Charts
import SwiftUI

struct StatsEmotionTrendSection: View {
    let points: [EmotionTrendChartPoint]
    let selectedRange: DoneChartRange
    let chartPresentation: StatsChartPresentation
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Pleasantness & energy",
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: "Scale",
                    value: "-1 to +1",
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            if points.isEmpty {
                StatsEmptyChartStateView(
                    systemImage: "heart.text.square.fill",
                    message: "Emotion logs will chart pleasantness and energy from -1 to +1.",
                    colorScheme: colorScheme
                )
            } else {
                metricLegend

                StatsHorizontalChartContainer(chartPresentation: chartPresentation, minHeight: 250) {
                    Chart {
                        RuleMark(y: .value("Neutral", 0))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.35))

                        ForEach(points) { point in
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Score", point.averageValence),
                                series: .value("Metric", "Pleasantness")
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(by: .value("Metric", "Pleasantness"))

                            PointMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Pleasantness", point.averageValence)
                            )
                            .symbolSize(symbolSize(for: point))
                            .foregroundStyle(by: .value("Metric", "Pleasantness"))

                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Score", point.averageArousal),
                                series: .value("Metric", "Energy")
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(by: .value("Metric", "Energy"))

                            PointMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Energy", point.averageArousal)
                            )
                            .symbolSize(symbolSize(for: point))
                            .foregroundStyle(by: .value("Metric", "Energy"))
                            .accessibilityLabel(point.date.formatted(.dateTime.month(.abbreviated).day()))
                            .accessibilityValue(accessibilityValue(for: point))
                        }
                    }
                    .chartYScale(domain: -1...1)
                    .chartForegroundStyleScale([
                        "Pleasantness": StatsEmotionTrendPalette.pleasantness(colorScheme: colorScheme),
                        "Energy": StatsEmotionTrendPalette.energy(colorScheme: colorScheme)
                    ])
                    .chartLegend(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [-1.0, 0.0, 1.0]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel {
                                if let score = value.as(Double.self) {
                                    Text(axisLabel(for: score))
                                        .font(.caption2.weight(.semibold))
                                        .multilineTextAlignment(.trailing)
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
                    .chartYAxisLabel("Daily average")
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

    private var subtitle: String {
        if logCount == 0 {
            return "Pleasantness and energy trends will appear after emotion logs."
        }
        let dayWord = points.count == 1 ? "day" : "days"
        return "\(logCount) emotion \(logCount == 1 ? "log" : "logs") across \(points.count) \(dayWord), averaged by day."
    }

    private var logCount: Int {
        points.reduce(0) { $0 + $1.logCount }
    }

    private var metricLegend: some View {
        HStack(alignment: .top, spacing: 10) {
            StatsEmotionTrendLegendItem(
                color: StatsEmotionTrendPalette.pleasantness(colorScheme: colorScheme),
                title: "Pleasantness",
                detail: "Unpleasant to pleasant"
            )

            StatsEmotionTrendLegendItem(
                color: StatsEmotionTrendPalette.energy(colorScheme: colorScheme),
                title: "Energy",
                detail: "Low to high energy"
            )
        }
    }

    private var peakIntensityPoint: EmotionTrendChartPoint? {
        EmotionTrendStats.highestIntensityDay(in: points)
    }

    private var peakIntensityText: String {
        guard let peakIntensityPoint else { return "0" }
        return peakIntensityPoint.averageIntensity.formatted(.number.precision(.fractionLength(1)))
    }

    private var doneAxisPoints: [DoneChartPoint] {
        points.map { DoneChartPoint(date: $0.date, count: max($0.logCount, 1)) }
    }

    private var insights: [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar",
                text: selectedRange.periodDescription
            ),
            StatsChartInsight(
                systemImage: "arrow.up.and.down",
                text: "Higher lines mean more pleasant or more energized days"
            ),
            peakIntensityPoint.map {
                StatsChartInsight(
                    systemImage: "heart.fill",
                    text: "Strongest logged day: intensity \(peakIntensityText) on \(chartPresentation.bestDayCaption(for: DoneChartPoint(date: $0.date, count: $0.logCount)))"
                )
            } ?? StatsChartInsight(
                systemImage: "heart.text.square",
                text: "Waiting for your first emotion log"
            )
        ]
    }

    private func symbolSize(for point: EmotionTrendChartPoint) -> CGFloat {
        min(120, 44 + CGFloat(point.logCount) * 12)
    }

    private func axisLabel(for score: Double) -> String {
        if score < 0 { return "Low\nUnpleasant" }
        if score > 0 { return "High\nPleasant" }
        return "Neutral"
    }

    private func accessibilityValue(for point: EmotionTrendChartPoint) -> String {
        let pleasantness = point.averageValence.formatted(.number.precision(.fractionLength(2)))
        let energy = point.averageArousal.formatted(.number.precision(.fractionLength(2)))
        let intensity = point.averageIntensity.formatted(.number.precision(.fractionLength(1)))
        return "Pleasantness \(pleasantness), energy \(energy), intensity \(intensity)"
    }
}

private struct StatsEmotionTrendLegendItem: View {
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .routinaGlassPill(tint: color, tintOpacity: 0.12)
    }
}

private enum StatsEmotionTrendPalette {
    static func pleasantness(colorScheme: ColorScheme) -> Color {
        Color.pink.opacity(colorScheme == .dark ? 0.82 : 0.7)
    }

    static func energy(colorScheme: ColorScheme) -> Color {
        Color.teal.opacity(colorScheme == .dark ? 0.82 : 0.68)
    }
}
