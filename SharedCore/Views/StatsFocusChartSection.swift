import Charts
import SwiftUI

struct StatsFocusChartSection: View {
    @Environment(\.calendar) private var calendar

    let subtitle: String
    let peakValue: String
    let focusChartPoints: [FocusDurationChartPoint]
    let focusWeekdayAveragePoints: [FocusWeekdayAverageChartPoint]
    let highlightedFocusDay: FocusDurationChartPoint?
    let highlightedFocusWeekdayAverage: FocusWeekdayAverageChartPoint?
    let averageFocusSecondsPerDay: TimeInterval
    let focusChartUpperBound: Double
    let focusWeekdayAverageUpperBound: Double
    let chartPresentation: StatsChartPresentation
    let highlightBarFill: LinearGradient
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme
    let insights: [StatsChartInsight]

    @State private var selectedGrouping: StatsFocusChartGrouping = .day
    @State private var selectedFocusPointID: Date?

    var body: some View {
        let displayPoints = selectedGrouping.points(from: focusChartPoints, calendar: calendar)
        let cumulativePoints = FocusDurationStats.cumulativePoints(from: focusChartPoints)
        let selectedPoint = selectedPoint(in: displayPoints)
        let peakPoint = FocusDurationStats.busiestDay(in: displayPoints)
        let focusBarXAxisDates = selectedGrouping.xAxisDates(from: displayPoints, chartPresentation: chartPresentation)
        let averageSeconds = averageSeconds(in: displayPoints)
        let focusAxisUpperBound = StatsChartTimeAxis.upperBound(for: displayUpperBound(in: displayPoints, averageSeconds: averageSeconds))
        let usesHorizontalScroll = selectedGrouping.usesHorizontalScroll(
            pointCount: displayPoints.count,
            chartPresentation: chartPresentation
        )
        let focusYAxisPosition: AxisMarkPosition = usesHorizontalScroll ? .trailing : .leading

        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: selectedGrouping.sectionTitle,
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: selectedGrouping.peakBadgeTitle,
                    value: peakPoint.map { chartPresentation.focusDurationText($0.seconds) } ?? peakValue,
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Focus chart period",
                options: StatsFocusChartGrouping.allCases,
                selection: $selectedGrouping,
                fillsAvailableWidth: true
            ) { grouping in
                Text(grouping.title)
            }
            .frame(maxWidth: 320)
            .accessibilityIdentifier("stats.focus.groupingPicker")

            StatsFocusChartContainer(
                usesHorizontalScroll: usesHorizontalScroll,
                minWidth: selectedGrouping.chartMinWidth(
                    pointCount: displayPoints.count,
                    chartPresentation: chartPresentation
                ),
                minHeight: 240
            ) {
                Chart {
                    ForEach(displayPoints) { point in
                        let isSelected = point.date == selectedPoint?.date
                        let isHighlighted = point.date == peakPoint?.date

                        BarMark(
                            x: .value(selectedGrouping.axisValueName, point.date, unit: selectedGrouping.chartUnit),
                            y: .value("Minutes", point.minutes)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isSelected || isHighlighted
                                ? AnyShapeStyle(highlightBarFill)
                                : AnyShapeStyle(StatsChartFill.focusBar(colorScheme: colorScheme))
                        )
                        .opacity(point.seconds == 0 ? 0.28 : 1)
                        .accessibilityLabel(selectedGrouping.detailTitle(for: point.date, calendar: calendar))
                        .accessibilityValue(accessibilityValue(for: point))
                    }

                    if averageSeconds > 0 {
                        RuleMark(y: .value("Average", averageSeconds / 60))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .annotation(
                                position: .topLeading,
                                alignment: .leading,
                                overflowResolution: .init(
                                    x: .fit(to: .chart),
                                    y: .disabled
                                )
                            ) {
                                Text("Avg \(chartPresentation.focusDurationText(averageSeconds))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(surfaceGradient, in: Capsule(style: .continuous))
                            }
                    }

                    if let selectedPoint {
                        RuleMark(
                            x: .value(
                                "Selected \(selectedGrouping.title)",
                                selectedPoint.date,
                                unit: selectedGrouping.chartUnit
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                        .foregroundStyle(Color.white.opacity(0.48))
                    }
                }
                .chartYScale(domain: 0...focusAxisUpperBound)
                .chartYAxis {
                    AxisMarks(
                        position: focusYAxisPosition,
                        values: StatsChartTimeAxis.values(upperBound: focusAxisUpperBound)
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
                    AxisMarks(values: focusBarXAxisDates) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisTick()
                            .foregroundStyle(Color.secondary.opacity(0.35))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(
                                    selectedGrouping.axisLabel(
                                        for: date,
                                        labeledDates: focusBarXAxisDates,
                                        chartPresentation: chartPresentation,
                                        calendar: calendar
                                    )
                                )
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.75))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                }
                .chartYAxisLabel("Focus time")
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
                                            points: displayPoints
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
                                            points: displayPoints
                                        )
                                    case .ended:
                                        selectedFocusPointID = nil
                                    }
                                }
                            #endif
                    }
                }
            }

            if let detailPoint = selectedPoint ?? peakPoint {
                StatsFocusPointDetailPanel(
                    title: selectedPoint == nil ? selectedGrouping.peakBadgeTitle : "Selected \(selectedGrouping.unitName)",
                    point: detailPoint,
                    grouping: selectedGrouping,
                    calendar: calendar,
                    colorScheme: colorScheme
                )
            }

            StatsFocusCumulativeChart(
                points: cumulativePoints,
                chartPresentation: chartPresentation,
                surfaceGradient: surfaceGradient,
                colorScheme: colorScheme
            )

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
                insights: visibleInsights(in: displayPoints, peakPoint: peakPoint),
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
        .onChange(of: selectedGrouping) { _, _ in
            selectedFocusPointID = nil
        }
    }

    private func selectedPoint(in points: [FocusDurationChartPoint]) -> FocusDurationChartPoint? {
        guard let selectedFocusPointID else { return nil }
        return points.first { $0.date == selectedFocusPointID }
    }

    private func averageSeconds(in points: [FocusDurationChartPoint]) -> TimeInterval {
        guard !points.isEmpty else { return 0 }
        return FocusDurationStats.totalSeconds(in: points) / Double(points.count)
    }

    private func displayUpperBound(
        in points: [FocusDurationChartPoint],
        averageSeconds: TimeInterval
    ) -> Double {
        let maxDisplayMinutes = points.map(\.minutes).max() ?? 0
        return max(10, ceil(max(maxDisplayMinutes, averageSeconds / 60)) + 5)
    }

    private func accessibilityValue(for point: FocusDurationChartPoint) -> String {
        var value = FocusSessionFormatting.durationText(seconds: point.seconds)
        let contributionSummary = point.contributions.prefix(3).map {
            "\($0.title) \(FocusSessionFormatting.durationText(seconds: $0.seconds))"
        }.joined(separator: ", ")
        if !contributionSummary.isEmpty {
            value += ". \(contributionSummary)"
        }
        return value
    }

    private func visibleInsights(
        in points: [FocusDurationChartPoint],
        peakPoint: FocusDurationChartPoint?
    ) -> [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: selectedGrouping.systemImage,
                text:
                    "\(insights.first?.text ?? chartPresentation.selectedRange.periodDescription) by \(selectedGrouping.title.lowercased())"
            ),
            peakPoint.map {
                StatsChartInsight(
                    systemImage: "timer",
                    text: "Best \(selectedGrouping.unitName): \(chartPresentation.focusDurationText($0.seconds))"
                )
            }
                ?? StatsChartInsight(
                    systemImage: "stopwatch",
                    text: "Waiting for your first focus session"
                ),
        ]
    }

    private func updateSelectedPoint(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        points: [FocusDurationChartPoint]
    ) {
        guard let plotFrame = proxy.plotFrame else {
            selectedFocusPointID = nil
            return
        }

        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            selectedFocusPointID = nil
            return
        }

        let xPosition = location.x - frame.origin.x
        guard let date: Date = proxy.value(atX: xPosition),
            let nearestPoint = nearestPoint(to: date, in: points)
        else {
            selectedFocusPointID = nil
            return
        }

        selectedFocusPointID = nearestPoint.date
    }

    private func nearestPoint(
        to date: Date,
        in points: [FocusDurationChartPoint]
    ) -> FocusDurationChartPoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }
}

struct StatsFocusChartContainer<Content: View>: View {
    let usesHorizontalScroll: Bool
    let minWidth: CGFloat
    let minHeight: CGFloat
    let content: () -> Content

    var body: some View {
        Group {
            if usesHorizontalScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    content()
                        .containerRelativeFrame(.horizontal)
                        .frame(minWidth: minWidth, minHeight: minHeight)
                        .padding(.top, 4)
                }
                .defaultScrollAnchor(.trailing)
            } else {
                content()
                    .frame(maxWidth: .infinity, minHeight: minHeight)
                    .padding(.top, 4)
            }
        }
    }
}

private struct StatsFocusPointDetailPanel: View {
    let title: String
    let point: FocusDurationChartPoint
    let grouping: StatsFocusChartGrouping
    let calendar: Calendar
    let colorScheme: ColorScheme

    private var visibleContributions: [FocusDurationContribution] {
        Array(point.contributions.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(FocusSessionFormatting.durationText(seconds: point.seconds))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(grouping.detailTitle(for: point.date, calendar: calendar))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            if visibleContributions.isEmpty {
                Text(point.seconds == 0 ? "No focus logged" : "No task detail")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(visibleContributions) { contribution in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(contribution.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text(FocusSessionFormatting.durationText(seconds: contribution.seconds))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    let hiddenCount = point.contributions.count - visibleContributions.count
                    if hiddenCount > 0 {
                        Text("+ \(hiddenCount) more")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .routinaGlassCard(cornerRadius: 16, tint: .accentColor, tintOpacity: colorScheme == .dark ? 0.18 : 0.12)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 12, y: 8)
    }
}
