import Charts
import SwiftUI

struct StatsFocusCumulativeChart: View {
    @Environment(\.calendar) private var calendar
    @State private var selectedPointID: Date?

    let points: [FocusCumulativeChartPoint]
    let chartPresentation: StatsChartPresentation
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    private var selectedPoint: FocusCumulativeChartPoint? {
        guard let selectedPointID else { return nil }
        return points.first { $0.date == selectedPointID }
    }

    private var totalSeconds: TimeInterval {
        points.last?.cumulativeSeconds ?? 0
    }

    private var axisUpperBound: Double {
        let maxMinutes = points.map(\.cumulativeMinutes).max() ?? 0
        return StatsChartTimeAxis.upperBound(for: max(10, maxMinutes + 5))
    }

    private var xAxisDates: [Date] {
        chartPresentation.focusCumulativeXAxisDates(from: points.map(\.date))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Cumulative focus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                StatsSmallHighlightBadge(
                    title: "Total",
                    value: chartPresentation.focusDurationText(totalSeconds),
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            StatsFocusChartContainer(
                usesHorizontalScroll: false,
                minWidth: 0,
                minHeight: 190
            ) {
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Cumulative minutes", point.cumulativeMinutes)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(cumulativeAreaFill)

                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Cumulative minutes", point.cumulativeMinutes)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Color.teal.opacity(colorScheme == .dark ? 0.92 : 0.78))
                        .accessibilityLabel(point.date.formatted(.dateTime.month(.abbreviated).day()))
                        .accessibilityValue(accessibilityValue(for: point))
                    }

                    if let lastPoint = points.last {
                        PointMark(
                            x: .value("Latest day", lastPoint.date, unit: .day),
                            y: .value("Cumulative minutes", lastPoint.cumulativeMinutes)
                        )
                        .symbolSize(34)
                        .foregroundStyle(Color.teal)
                    }

                    if let selectedPoint {
                        RuleMark(x: .value("Selected day", selectedPoint.date, unit: .day))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.48))

                        PointMark(
                            x: .value("Selected day", selectedPoint.date, unit: .day),
                            y: .value("Cumulative minutes", selectedPoint.cumulativeMinutes)
                        )
                        .symbolSize(54)
                        .foregroundStyle(Color.white)
                    }
                }
                .chartYScale(domain: 0...axisUpperBound)
                .chartYAxis {
                    AxisMarks(
                        position: .leading,
                        values: StatsChartTimeAxis.values(upperBound: axisUpperBound)
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
                    AxisMarks(values: xAxisDates) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(
                                    chartPresentation.focusDayXAxisLabel(
                                        for: date,
                                        in: xAxisDates,
                                        calendar: calendar
                                    )
                                )
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
                .chartYAxisLabel("Cumulative focus")
                .chartPlotStyle { plotArea in
                    plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelectedPoint(
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
                                        updateSelectedPoint(
                                            at: location,
                                            proxy: proxy,
                                            geometry: geometry
                                        )
                                    case .ended:
                                        selectedPointID = nil
                                    }
                                }
                            #endif
                    }
                }
                .frame(height: 190)
            }

            if let detailPoint = selectedPoint ?? points.last,
                totalSeconds > 0
            {
                StatsFocusCumulativePointPanel(
                    title: selectedPoint == nil ? "Total" : "Selected day",
                    point: detailPoint,
                    colorScheme: colorScheme
                )
            }
        }
        .padding(.top, 2)
    }

    private var cumulativeAreaFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.teal.opacity(colorScheme == .dark ? 0.26 : 0.18),
                Color.teal.opacity(0.02),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func accessibilityValue(for point: FocusCumulativeChartPoint) -> String {
        let total = FocusSessionFormatting.durationText(seconds: point.cumulativeSeconds)
        let daily = FocusSessionFormatting.durationText(seconds: point.dailySeconds)
        return "\(total) total, \(daily) that day"
    }

    private func updateSelectedPoint(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else {
            selectedPointID = nil
            return
        }

        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            selectedPointID = nil
            return
        }

        let xPosition = location.x - frame.origin.x
        guard let date: Date = proxy.value(atX: xPosition),
            let nearestPoint = nearestPoint(to: date)
        else {
            selectedPointID = nil
            return
        }

        selectedPointID = nearestPoint.date
    }

    private func nearestPoint(to date: Date) -> FocusCumulativeChartPoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }
}

private struct StatsFocusCumulativePointPanel: View {
    let title: String
    let point: FocusCumulativeChartPoint
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(FocusSessionFormatting.durationText(seconds: point.cumulativeSeconds))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(point.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text("Day: \(FocusSessionFormatting.durationText(seconds: point.dailySeconds))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .padding(12)
        .routinaGlassCard(cornerRadius: 16, tint: .teal, tintOpacity: colorScheme == .dark ? 0.18 : 0.12)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 12, y: 8)
    }
}
