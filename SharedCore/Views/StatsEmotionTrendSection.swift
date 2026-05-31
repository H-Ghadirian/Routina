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
                title: "Emotion trends",
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: "Peak intensity",
                    value: peakIntensityText,
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            if points.isEmpty {
                StatsEmptyChartStateView(
                    systemImage: "heart.text.square.fill",
                    message: "Emotion logs will chart pleasantness, energy, and intensity over time.",
                    colorScheme: colorScheme
                )
            } else {
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
                    .chartLegend(position: .bottom, alignment: .leading)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [-1.0, 0.0, 1.0]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel {
                                if let score = value.as(Double.self) {
                                    Text(axisLabel(for: score))
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
        let logCount = points.reduce(0) { $0 + $1.logCount }
        if logCount == 0 {
            return "Pleasantness and energy trends will appear after emotion logs."
        }
        let dayWord = points.count == 1 ? "day" : "days"
        return "\(logCount) emotion \(logCount == 1 ? "log" : "logs") across \(points.count) \(dayWord)."
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
            peakIntensityPoint.map {
                StatsChartInsight(
                    systemImage: "heart.fill",
                    text: "Peak intensity: \(peakIntensityText) on \(chartPresentation.bestDayCaption(for: DoneChartPoint(date: $0.date, count: $0.logCount)))"
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
        if score < 0 { return "Low" }
        if score > 0 { return "High" }
        return "0"
    }

    private func accessibilityValue(for point: EmotionTrendChartPoint) -> String {
        let pleasantness = point.averageValence.formatted(.number.precision(.fractionLength(2)))
        let energy = point.averageArousal.formatted(.number.precision(.fractionLength(2)))
        let intensity = point.averageIntensity.formatted(.number.precision(.fractionLength(1)))
        return "Pleasantness \(pleasantness), energy \(energy), intensity \(intensity)"
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
