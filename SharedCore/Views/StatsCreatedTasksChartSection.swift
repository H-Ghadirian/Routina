import Charts
import SwiftUI

struct StatsCreatedTasksChartSection: View {
    private static let taskTypePickerWidth: CGFloat = 280

    let metrics: StatsFeatureMetrics
    let selectedRange: DoneChartRange
    let selectedTaskTypeFilter: StatsTaskTypeFilter
    let chartPresentation: StatsChartPresentation
    let createdTasksPresentation: StatsCreatedTasksPresentation
    let createdBarFill: LinearGradient
    let highlightBarFill: LinearGradient
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme
    let onSelectTaskTypeFilter: (StatsTaskTypeFilter) -> Void

    @State private var selectedCreatedPointID: Date?

    var body: some View {
        let createdXAxisDates = chartPresentation.dailyBarXAxisDates(from: metrics.createdChartPoints)
        let createdAxisUpperBound = StatsChartCountAxis.upperBound(for: metrics.createdChartUpperBound)
        let createdYAxisPosition: AxisMarkPosition = chartPresentation.usesHorizontalChartScroll ? .trailing : .leading
        let selectedCreatedPoint = selectedPoint(in: metrics.createdChartPoints)

        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Tasks created per day",
                subtitle: createdTasksPresentation.chartSubtitle(
                    totalCount: metrics.createdTotalCount,
                    activeDayCount: metrics.createdActiveDayCount
                )
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Created task type",
                        options: StatsTaskTypeFilter.allCases,
                        selection: selectedTaskTypeFilterBinding,
                        fillsAvailableWidth: true
                    ) { filter in
                        Text(filter.rawValue)
                    }
                    .frame(width: Self.taskTypePickerWidth)
                    .accessibilityIdentifier("stats.createdTasks.typePicker")

                    StatsSmallHighlightBadge(
                        title: "Created",
                        value: metrics.createdTotalCount.formatted(),
                        colorScheme: colorScheme,
                        surfaceGradient: surfaceGradient
                    )
                }
            }

            StatsHorizontalChartContainer(chartPresentation: chartPresentation, minHeight: 240) {
                Chart {
                    ForEach(metrics.createdChartPoints) { point in
                        let isSelected = point.date == selectedCreatedPoint?.date
                        let isHighlighted = point.date == metrics.highlightedCreatedDay?.date

                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Created", point.count)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isSelected || isHighlighted
                                ? AnyShapeStyle(highlightBarFill)
                                : AnyShapeStyle(createdBarFill)
                        )
                        .opacity(point.count == 0 ? 0.35 : 1)
                    }

                    if metrics.createdAveragePerDay > 0 {
                        RuleMark(y: .value("Average", metrics.createdAveragePerDay))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .annotation(position: .topLeading, alignment: .leading) {
                                Text("Avg \(chartPresentation.averagePerDayText(for: metrics.createdAveragePerDay))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(surfaceGradient, in: Capsule(style: .continuous))
                            }
                    }

                    if let highlightedCreatedDay = metrics.highlightedCreatedDay {
                        PointMark(
                            x: .value("Date", highlightedCreatedDay.date, unit: .day),
                            y: .value("Created", highlightedCreatedDay.count)
                        )
                        .symbolSize(selectedRange == .year ? 46 : 64)
                        .foregroundStyle(Color.white)
                    }

                    if let selectedCreatedPoint {
                        RuleMark(x: .value("Selected day", selectedCreatedPoint.date, unit: .day))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.48))
                    }
                }
                .chartYScale(domain: 0...createdAxisUpperBound)
                .chartYAxis {
                    AxisMarks(
                        position: createdYAxisPosition,
                        values: StatsChartCountAxis.values(upperBound: createdAxisUpperBound)
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
                    AxisMarks(values: createdXAxisDates) { value in
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
                .chartYAxisLabel("Created tasks")
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
                                            points: metrics.createdChartPoints
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
                                        points: metrics.createdChartPoints
                                    )
                                case .ended:
                                    selectedCreatedPointID = nil
                                }
                            }
                        #endif
                    }
                }
            }

            if let detailPoint = selectedCreatedPoint ?? metrics.highlightedCreatedDay ?? metrics.createdChartPoints.last {
                StatsCreatedTasksPointDetailPanel(
                    title: selectedCreatedPoint == nil
                        ? (metrics.highlightedCreatedDay == nil ? "Latest day" : "Most created")
                        : "Selected day",
                    point: detailPoint,
                    chartPresentation: chartPresentation,
                    colorScheme: colorScheme
                )
            }

            StatsChartInsightRow(
                insights: StatsChartInsightBuilder.createdTasksInsights(
                    metrics: metrics,
                    createdTasksPresentation: createdTasksPresentation,
                    chartPresentation: chartPresentation
                ),
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }

    private var selectedTaskTypeFilterBinding: Binding<StatsTaskTypeFilter> {
        Binding(
            get: { selectedTaskTypeFilter },
            set: { onSelectTaskTypeFilter($0) }
        )
    }

    private func selectedPoint(in points: [DoneChartPoint]) -> DoneChartPoint? {
        guard let selectedCreatedPointID else { return nil }
        return points.first { $0.date == selectedCreatedPointID }
    }

    private func updateSelectedPoint(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        points: [DoneChartPoint]
    ) {
        guard let plotFrame = proxy.plotFrame else {
            selectedCreatedPointID = nil
            return
        }

        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            selectedCreatedPointID = nil
            return
        }

        let xPosition = location.x - frame.origin.x
        guard let date: Date = proxy.value(atX: xPosition),
              let nearestPoint = nearestPoint(to: date, in: points) else {
            selectedCreatedPointID = nil
            return
        }

        selectedCreatedPointID = nearestPoint.date
    }

    private func nearestPoint(
        to date: Date,
        in points: [DoneChartPoint]
    ) -> DoneChartPoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }
}

private struct StatsCreatedTasksPointDetailPanel: View {
    let title: String
    let point: DoneChartPoint
    let chartPresentation: StatsChartPresentation
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(point.count.formatted())
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(chartPresentation.bestDayCaption(for: point))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(detailText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
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

    private var detailText: String {
        switch point.count {
        case 0:
            return "No tasks created"
        case 1:
            return "1 task created"
        default:
            return "\(point.count) tasks created"
        }
    }
}
