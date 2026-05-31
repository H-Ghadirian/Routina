import Charts
import SwiftUI

struct StatsCreatedTasksChartSection: View {
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

    var body: some View {
        let createdXAxisDates = chartPresentation.dailyBarXAxisDates(from: metrics.createdChartPoints)
        let createdAxisUpperBound = StatsChartCountAxis.upperBound(for: metrics.createdChartUpperBound)
        let createdYAxisPosition: AxisMarkPosition = chartPresentation.usesHorizontalChartScroll ? .trailing : .leading

        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Tasks created per day",
                subtitle: createdTasksPresentation.chartSubtitle(
                    totalCount: metrics.createdTotalCount,
                    activeDayCount: metrics.createdActiveDayCount
                )
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    Picker("Created task type", selection: selectedTaskTypeFilterBinding) {
                        ForEach(StatsTaskTypeFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
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
                        let isHighlighted = point.date == metrics.highlightedCreatedDay?.date

                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Created", point.count)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isHighlighted
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
}
