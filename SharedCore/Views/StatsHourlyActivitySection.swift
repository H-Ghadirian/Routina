import Charts
import SwiftUI

struct StatsHourlyActivitySection: View {
    let points: [HourlyActivityChartPoint]
    let selectedRange: DoneChartRange
    let chartPresentation: StatsChartPresentation
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    @State private var selectedMetric: StatsHourlyActivityMetric = .focus
    @State private var selectedHour: Int?

    var body: some View {
        let selectedPoint = selectedPoint(in: points)

        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "24-hour rhythm",
                subtitle: "See which hours hold your focus, done work, created tasks, and timeline activity."
            ) {
                StatsSmallHighlightBadge(
                    title: "Peak hour",
                    value: peakHourText,
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            Picker("Hourly metric", selection: $selectedMetric) {
                ForEach(StatsHourlyActivityMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("stats.hourlyActivity.metricPicker")

            if points.allSatisfy({ !$0.hasActivity }) {
                StatsEmptyChartStateView(
                    systemImage: "clock.badge.questionmark",
                    message: "Hourly focus, completion, and creation patterns will appear here.",
                    colorScheme: colorScheme
                )
            } else {
                Chart {
                    ForEach(points) { point in
                        let isSelected = point.hour == selectedPoint?.hour
                        let isHighlighted = point.hour == peakPoint?.hour && selectedValue(for: point) > 0

                        BarMark(
                            x: .value("Hour", Double(point.hour)),
                            y: .value(selectedMetric.axisValueName, selectedValue(for: point))
                        )
                        .cornerRadius(6)
                        .foregroundStyle(
                            isSelected || isHighlighted
                                ? AnyShapeStyle(StatsDashboardPalette.highlightBarFill)
                                : selectedMetric.fill(colorScheme: colorScheme)
                        )
                        .opacity(selectedValue(for: point) == 0 ? 0.28 : 1)
                        .accessibilityLabel(hourLabel(for: point.hour))
                        .accessibilityValue(accessibilityValue(for: point))
                    }

                    if let selectedPoint {
                        RuleMark(x: .value("Selected hour", Double(selectedPoint.hour)))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.48))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 250)
                .padding(.top, 4)
                .chartXScale(domain: -0.5...23.5)
                .chartYScale(domain: 0...yAxisUpperBound)
                .chartYAxis {
                    AxisMarks(
                        position: .leading,
                        values: yAxisValues
                    ) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let numericValue = value.as(Double.self) {
                                Text(yAxisLabel(for: numericValue))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0.0, 6.0, 12.0, 18.0, 23.0]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisTick()
                        AxisValueLabel {
                            if let hour = value.as(Double.self) {
                                Text(hourLabel(for: Int(hour.rounded())))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxisLabel(selectedMetric.axisLabel)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelectedHour(
                                            at: value.location,
                                            proxy: proxy,
                                            geometry: geometry
                                        )
                                    }
                            )
                        #if os(macOS)
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    updateSelectedHour(
                                        at: location,
                                        proxy: proxy,
                                        geometry: geometry
                                    )
                                case .ended:
                                    selectedHour = nil
                                }
                            }
                        #endif
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                }
            }

            if let detailPoint = selectedPoint ?? positivePeakPoint {
                StatsHourlyActivityPointDetailPanel(
                    title: selectedPoint == nil ? "Peak hour" : "Selected hour",
                    point: detailPoint,
                    metric: selectedMetric,
                    selectedRange: selectedRange,
                    chartPresentation: chartPresentation,
                    colorScheme: colorScheme
                )
            }

            StatsChartInsightRow(
                insights: insights,
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
        .onChange(of: selectedMetric) { _, _ in
            selectedHour = nil
        }
    }

    private var peakPoint: HourlyActivityChartPoint? {
        points.max { lhs, rhs in
            let lhsValue = selectedValue(for: lhs)
            let rhsValue = selectedValue(for: rhs)
            if lhsValue == rhsValue {
                return lhs.hour > rhs.hour
            }
            return lhsValue < rhsValue
        }
    }

    private var peakHourText: String {
        guard let peakPoint, selectedValue(for: peakPoint) > 0 else { return "None" }
        return hourLabel(for: peakPoint.hour)
    }

    private var positivePeakPoint: HourlyActivityChartPoint? {
        guard let peakPoint, selectedValue(for: peakPoint) > 0 else { return nil }
        return peakPoint
    }

    private var totalValue: Double {
        points.reduce(0) { $0 + selectedValue(for: $1) }
    }

    private var yAxisUpperBound: Double {
        switch selectedMetric {
        case .focus:
            return StatsChartTimeAxis.upperBound(for: max(10, maxSelectedValue))
        case .done, .created, .activity:
            return StatsChartCountAxis.upperBound(for: max(1, maxSelectedValue))
        }
    }

    private var yAxisValues: [Double] {
        switch selectedMetric {
        case .focus:
            return StatsChartTimeAxis.values(upperBound: yAxisUpperBound)
        case .done, .created, .activity:
            return StatsChartCountAxis.values(upperBound: yAxisUpperBound)
        }
    }

    private var maxSelectedValue: Double {
        points.map(selectedValue(for:)).max() ?? 0
    }

    private var insights: [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "clock",
                text: selectedRange.periodDescription
            ),
            StatsChartInsight(
                systemImage: selectedMetric.systemImage,
                text: "\(selectedMetric.totalLabel): \(selectedMetric.formattedValue(totalValue, chartPresentation: chartPresentation))"
            ),
            positivePeakPoint.map {
                StatsChartInsight(
                    systemImage: "sparkles",
                    text: "Strongest hour: \(hourLabel(for: $0.hour))"
                )
            } ?? StatsChartInsight(
                systemImage: "clock.badge.questionmark",
                text: "Waiting for hourly activity"
            )
        ]
    }

    private func selectedPoint(in points: [HourlyActivityChartPoint]) -> HourlyActivityChartPoint? {
        guard let selectedHour else { return nil }
        return points.first { $0.hour == selectedHour }
    }

    private func selectedValue(for point: HourlyActivityChartPoint) -> Double {
        switch selectedMetric {
        case .focus:
            return point.focusMinutes
        case .done:
            return Double(point.doneCount)
        case .created:
            return Double(point.createdCount)
        case .activity:
            return Double(point.activityCount)
        }
    }

    private func yAxisLabel(for value: Double) -> String {
        switch selectedMetric {
        case .focus:
            return StatsChartTimeAxis.label(for: value)
        case .done, .created, .activity:
            return StatsChartCountAxis.label(for: value)
        }
    }

    private func accessibilityValue(for point: HourlyActivityChartPoint) -> String {
        let valueText = selectedMetric.formattedValue(
            selectedValue(for: point),
            chartPresentation: chartPresentation
        )
        return "\(valueText), \(hourRangeLabel(for: point.hour)), \(selectedRange.periodDescription)"
    }

    private func hourLabel(for hour: Int) -> String {
        StatsHourlyActivityHourFormatting.label(for: hour)
    }

    private func hourRangeLabel(for hour: Int) -> String {
        StatsHourlyActivityHourFormatting.rangeLabel(for: hour)
    }

    private func updateSelectedHour(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else {
            selectedHour = nil
            return
        }

        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            selectedHour = nil
            return
        }

        let xPosition = location.x - frame.origin.x
        guard let hour: Double = proxy.value(atX: xPosition),
              let nearestPoint = nearestPoint(to: hour, in: points) else {
            selectedHour = nil
            return
        }

        selectedHour = nearestPoint.hour
    }

    private func nearestPoint(
        to hour: Double,
        in points: [HourlyActivityChartPoint]
    ) -> HourlyActivityChartPoint? {
        points.min { lhs, rhs in
            abs(Double(lhs.hour) - hour) < abs(Double(rhs.hour) - hour)
        }
    }
}

private struct StatsHourlyActivityPointDetailPanel: View {
    let title: String
    let point: HourlyActivityChartPoint
    let metric: StatsHourlyActivityMetric
    let selectedRange: DoneChartRange
    let chartPresentation: StatsChartPresentation
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(metric.formattedValue(metric.value(in: point), chartPresentation: chartPresentation))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(StatsHourlyActivityHourFormatting.rangeLabel(for: point.hour))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(metric.detailText(value: metric.value(in: point), selectedRange: selectedRange))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .routinaGlassCard(cornerRadius: 16, tint: metric.tint, tintOpacity: colorScheme == .dark ? 0.18 : 0.12)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 12, y: 8)
    }
}

private enum StatsHourlyActivityHourFormatting {
    static func label(for hour: Int) -> String {
        let normalizedHour = ((hour % 24) + 24) % 24
        switch normalizedHour {
        case 0:
            return "12 AM"
        case 1..<12:
            return "\(normalizedHour) AM"
        case 12:
            return "12 PM"
        default:
            return "\(normalizedHour - 12) PM"
        }
    }

    static func rangeLabel(for hour: Int) -> String {
        "\(label(for: hour))-\(label(for: hour + 1))"
    }
}

private enum StatsHourlyActivityMetric: String, CaseIterable, Identifiable {
    case focus
    case done
    case created
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .done:
            return "Done"
        case .created:
            return "Created"
        case .activity:
            return "Activity"
        }
    }

    var axisLabel: String {
        switch self {
        case .focus:
            return "Focus time"
        case .done:
            return "Done tasks"
        case .created:
            return "Created tasks"
        case .activity:
            return "Timeline activity"
        }
    }

    var axisValueName: String {
        switch self {
        case .focus:
            return "Focus minutes"
        case .done:
            return "Done"
        case .created:
            return "Created"
        case .activity:
            return "Activity"
        }
    }

    var totalLabel: String {
        switch self {
        case .focus:
            return "Total focus"
        case .done:
            return "Done"
        case .created:
            return "Created"
        case .activity:
            return "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .focus:
            return "timer"
        case .done:
            return "checkmark.seal.fill"
        case .created:
            return "plus.circle.fill"
        case .activity:
            return "chart.bar.fill"
        }
    }

    var tint: Color {
        switch self {
        case .focus:
            return .accentColor
        case .done:
            return .green
        case .created:
            return .teal
        case .activity:
            return .indigo
        }
    }

    func value(in point: HourlyActivityChartPoint) -> Double {
        switch self {
        case .focus:
            return point.focusMinutes
        case .done:
            return Double(point.doneCount)
        case .created:
            return Double(point.createdCount)
        case .activity:
            return Double(point.activityCount)
        }
    }

    func fill(colorScheme: ColorScheme) -> AnyShapeStyle {
        switch self {
        case .focus:
            return AnyShapeStyle(StatsChartFill.focusBar(colorScheme: colorScheme))
        case .done:
            return AnyShapeStyle(Color.green.opacity(colorScheme == .dark ? 0.82 : 0.68))
        case .created:
            return AnyShapeStyle(StatsDashboardPalette.createdBarFill(colorScheme: colorScheme))
        case .activity:
            return AnyShapeStyle(Color.indigo.opacity(colorScheme == .dark ? 0.82 : 0.68))
        }
    }

    func formattedValue(_ value: Double, chartPresentation: StatsChartPresentation) -> String {
        switch self {
        case .focus:
            return chartPresentation.focusDurationText(TimeInterval(value.rounded() * 60))
        case .done, .created, .activity:
            return Int(value.rounded()).formatted()
        }
    }

    func detailText(value: Double, selectedRange: DoneChartRange) -> String {
        let rangeText = selectedRange.hourlyActivityRangePhrase

        switch self {
        case .focus:
            if value <= 0 {
                return "No focus landed in this hour bucket \(rangeText)."
            }
            return "Focus sessions are split by clock hour, then totaled \(rangeText)."
        case .done:
            if value <= 0 {
                return "No completed work was timestamped in this hour \(rangeText)."
            }
            return "Completed work timestamped in this hour \(rangeText)."
        case .created:
            if value <= 0 {
                return "No tasks were created in this hour \(rangeText)."
            }
            return "Tasks created in this hour \(rangeText)."
        case .activity:
            if value <= 0 {
                return "No timeline entries were timestamped in this hour \(rangeText)."
            }
            return "Timeline entries timestamped in this hour \(rangeText)."
        }
    }
}

private extension DoneChartRange {
    var hourlyActivityRangePhrase: String {
        switch self {
        case .today:
            return "today"
        case .week, .month, .year:
            return "across the \(periodDescription.lowercased())"
        }
    }
}
