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

    @State private var selectedActivityPointID: Date?

    var body: some View {
        let activityAxisUpperBound = StatsChartCountAxis.upperBound(for: chartUpperBound)
        let activityYAxisPosition: AxisMarkPosition = chartPresentation.usesHorizontalChartScroll ? .trailing : .leading
        let displayOutcomePoints = outcomeDisplayPoints
        let selectedActivityPoint = selectedPoint(in: displayOutcomePoints)
        let highlightedActivityPoint = highlightedOutcomePoint(in: displayOutcomePoints)

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

                    if let selectedActivityPoint {
                        RuleMark(x: .value("Selected day", selectedActivityPoint.date, unit: .day))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.48))
                    }
                }
                .chartYScale(domain: 0...activityAxisUpperBound)
                .chartForegroundStyleScale([
                    "Done": StatsOutcomeChartPalette.done(colorScheme: colorScheme),
                    "Missed": StatsOutcomeChartPalette.missed(colorScheme: colorScheme),
                    "Canceled": StatsOutcomeChartPalette.canceled(colorScheme: colorScheme)
                ])
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis {
                    AxisMarks(
                        position: activityYAxisPosition,
                        values: StatsChartCountAxis.values(upperBound: activityAxisUpperBound)
                    ) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let count = value.as(Double.self) {
                                Text(StatsChartCountAxis.label(for: count))
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
                .chartYAxisLabel("Activity")
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
                                            geometry: geometry,
                                            points: displayOutcomePoints
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
                                        geometry: geometry,
                                        points: displayOutcomePoints
                                    )
                                case .ended:
                                    selectedActivityPointID = nil
                                }
                            }
                        #endif
                    }
                }
            }

            if let detailPoint = selectedActivityPoint ?? highlightedActivityPoint ?? displayOutcomePoints.last {
                StatsTimelineActivityPointDetailPanel(
                    title: selectedActivityPoint == nil
                        ? (highlightedActivityPoint == nil ? "Latest day" : "Peak day")
                        : "Selected day",
                    point: detailPoint,
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
    }

    private var outcomeDisplayPoints: [OutcomeMixChartPoint] {
        outcomePoints.isEmpty
            ? chartPoints.map {
                OutcomeMixChartPoint(
                    date: $0.date,
                    doneCount: $0.count,
                    missedCount: 0,
                    canceledCount: 0
                )
            }
            : outcomePoints
    }

    private var outcomeSegments: [StatsOutcomeChartSegment] {
        outcomeDisplayPoints.flatMap { point in
            [
                StatsOutcomeChartSegment(date: point.date, kind: .completed, count: point.doneCount),
                StatsOutcomeChartSegment(date: point.date, kind: .missed, count: point.missedCount),
                StatsOutcomeChartSegment(date: point.date, kind: .canceled, count: point.canceledCount)
            ].filter { $0.count > 0 }
        }
    }

    private func selectedPoint(in points: [OutcomeMixChartPoint]) -> OutcomeMixChartPoint? {
        guard let selectedActivityPointID else { return nil }
        return points.first { $0.date == selectedActivityPointID }
    }

    private func highlightedOutcomePoint(in points: [OutcomeMixChartPoint]) -> OutcomeMixChartPoint? {
        guard let highlightedPoint else { return nil }
        return points.first { $0.date == highlightedPoint.date }
            ?? OutcomeMixChartPoint(
                date: highlightedPoint.date,
                doneCount: highlightedPoint.count,
                missedCount: 0,
                canceledCount: 0
            )
    }

    private func updateSelectedPoint(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        points: [OutcomeMixChartPoint]
    ) {
        guard let plotFrame = proxy.plotFrame else {
            selectedActivityPointID = nil
            return
        }

        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            selectedActivityPointID = nil
            return
        }

        let xPosition = location.x - frame.origin.x
        guard let date: Date = proxy.value(atX: xPosition),
              let nearestPoint = nearestPoint(to: date, in: points) else {
            selectedActivityPointID = nil
            return
        }

        selectedActivityPointID = nearestPoint.date
    }

    private func nearestPoint(
        to date: Date,
        in points: [OutcomeMixChartPoint]
    ) -> OutcomeMixChartPoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
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

private struct StatsTimelineActivityPointDetailPanel: View {
    let title: String
    let point: OutcomeMixChartPoint
    let chartPresentation: StatsChartPresentation
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(point.totalCount.formatted())
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(chartPresentation.bestDayCaption(for: DoneChartPoint(date: point.date, count: point.totalCount)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                outcomePill(title: "Done", count: point.doneCount, color: StatsOutcomeChartPalette.done(colorScheme: colorScheme))
                outcomePill(title: "Missed", count: point.missedCount, color: StatsOutcomeChartPalette.missed(colorScheme: colorScheme))
                outcomePill(title: "Canceled", count: point.canceledCount, color: StatsOutcomeChartPalette.canceled(colorScheme: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .routinaGlassCard(cornerRadius: 16, tint: .green, tintOpacity: colorScheme == .dark ? 0.18 : 0.12)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 12, y: 8)
    }

    private func outcomePill(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text("\(title) \(count.formatted())")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(colorScheme == .dark ? 0.16 : 0.1), in: Capsule(style: .continuous))
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
