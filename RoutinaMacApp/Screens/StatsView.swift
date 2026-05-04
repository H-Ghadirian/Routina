import Charts
import ComposableArchitecture
import SwiftData
import SwiftUI

struct StatsViewWrapper: View {
    let store: StoreOf<StatsFeature>

    var body: some View {
        StatsView(store: store)
    }
}

struct StatsView: View {
    let store: StoreOf<StatsFeature>
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]
    @Query private var focusSessions: [FocusSession]
    @State private var isActiveItemsInfoPresented = false

    private typealias Metrics = StatsFeature.Metrics

    private var chartPresentation: StatsChartPresentation {
        StatsChartPresentation(
            selectedRange: selectedRange,
            isCompact: horizontalSizeClass == .compact
        )
    }

    private var createdTasksPresentation: StatsCreatedTasksPresentation {
        StatsCreatedTasksPresentation(
            taskTypeFilter: selectedCreatedChartTaskTypeFilter,
            selectedRange: selectedRange
        )
    }

    private var selectedRange: DoneChartRange {
        store.selectedRange
    }

    private var selectedTaskTypeFilter: StatsTaskTypeFilter {
        store.taskTypeFilter
    }

    private var selectedCreatedChartTaskTypeFilter: StatsTaskTypeFilter {
        store.createdChartTaskTypeFilter
    }

    private var metrics: Metrics {
        store.metrics
    }

    private var filteredTaskCount: Int {
        store.filteredTaskCount
    }

    private var activeItemsBreakdown: StatsActiveItemsBreakdown {
        StatsActiveItemsBreakdown(
            tasks: filteredTasksForCurrentStatsFilters,
            calendar: calendar
        )
    }

    private var filteredTasksForCurrentStatsFilters: [RoutineTask] {
        StatsTaskFilterResolver(
            taskTypeFilter: selectedTaskTypeFilter,
            selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
            selectedTags: store.effectiveSelectedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            excludedTags: store.excludedTags,
            excludeTagMatchMode: store.excludeTagMatchMode
        )
        .filteredTasks(from: tasks)
    }

    private var gitHubConnection: GitHubConnectionStatus {
        store.gitHubConnection
    }

    private var gitHubStats: GitHubStatsSnapshot? {
        store.gitHubStats
    }

    private var isGitHubStatsLoading: Bool {
        store.isGitHubStatsLoading
    }

    private var gitHubStatsErrorMessage: String? {
        store.gitHubStatsErrorMessage
    }

    private var surfaceGradient: LinearGradient {
        StatsDashboardPalette.surfaceGradient(colorScheme: colorScheme)
    }

    private var heroGradient: LinearGradient {
        StatsDashboardPalette.heroGradient(colorScheme: colorScheme)
    }

    private var pageBackground: LinearGradient {
        StatsDashboardPalette.pageBackground(colorScheme: colorScheme)
    }

    private var selectorBackground: LinearGradient {
        StatsDashboardPalette.selectorBackground(colorScheme: colorScheme)
    }

    private var selectorActiveFill: LinearGradient {
        StatsDashboardPalette.selectorActiveFill
    }

    private var baseBarFill: LinearGradient {
        StatsDashboardPalette.baseBarFill(colorScheme: colorScheme)
    }

    private var createdBarFill: LinearGradient {
        StatsDashboardPalette.createdBarFill(colorScheme: colorScheme)
    }

    private var highlightBarFill: LinearGradient {
        StatsDashboardPalette.highlightBarFill
    }

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                StatsDashboardScrollContainer(
                    pageBackground: pageBackground,
                    bottomPadding: contentBottomPadding,
                    maxContentWidth: statsContentMaxWidth
                ) {
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection(metrics: metrics)
                        summaryCards(metrics: metrics)
                        createdTasksChartSection(metrics: metrics)
                        if selectedRange != .today {
                            chartSection(metrics: metrics)
                        }
                        tagUsageSection(metrics: metrics)
                        if selectedRange != .today {
                            focusChartSection(metrics: metrics)
                        }
                        if store.isGitFeaturesEnabled {
                            gitHubSection
                        }
                    }
                }
                .navigationTitle("Stats")
            }
            .statsDataRefresh(
                tasks: tasks,
                logs: logs,
                focusSessions: focusSessions,
                onAppear: { store.send(.onAppear) },
                onDataChanged: { tasks, logs, focusSessions in
                    store.send(.setData(tasks: tasks, logs: logs, focusSessions: focusSessions))
                }
            )
        }
    }

    private func heroSection(metrics: Metrics) -> some View {
        StatsHeroSectionView(
            selectedRange: selectedRange,
            totalCount: metrics.totalCount,
            activeDayCount: metrics.activeDayCount,
            averagePerDay: metrics.averagePerDay,
            highlightedBusiestDay: metrics.highlightedBusiestDay,
            sparklinePoints: metrics.sparklinePoints,
            sparklineMaxCount: metrics.sparklineMaxCount,
            periodDescription: StatsChartInsightBuilder.userActivityPeriodDescription(
                selectedRange: selectedRange,
                chartPoints: metrics.chartPoints
            ),
            chartPresentation: chartPresentation,
            colorScheme: colorScheme,
            heroGradient: heroGradient
        )
    }

    private func summaryCards(metrics: Metrics) -> some View {
        StatsSummaryGrid(
            items: StatsSummaryCardItemBuilder.items(
                metrics: metrics,
                selectedRange: selectedRange,
                chartPresentation: chartPresentation,
                taskTypeFilter: selectedTaskTypeFilter,
                filteredTaskCount: filteredTaskCount,
                showsActiveAccessory: true
            ),
            minimumCardWidth: horizontalSizeClass == .compact ? 160 : 220,
            colorScheme: colorScheme,
            surfaceGradient: surfaceGradient
        ) { item in
            Group {
                if item.showsAccessory {
                    activeItemsInfoButton
                }
            }
        }
    }

    private var gitHubSection: some View {
        StatsMacGitHubSection(
            connection: gitHubConnection,
            stats: gitHubStats,
            errorMessage: gitHubStatsErrorMessage,
            isLoading: isGitHubStatsLoading,
            selectedRange: selectedRange,
            horizontalSizeClass: horizontalSizeClass,
            colorScheme: colorScheme,
            calendar: calendar,
            onRefresh: { store.send(.gitHubStatsRefreshRequested) }
        )
    }

    private func createdTasksChartSection(metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Tasks created per day",
                subtitle: createdTasksPresentation.chartSubtitle(
                        totalCount: metrics.createdTotalCount,
                        activeDayCount: metrics.createdActiveDayCount
                )
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    Picker("Created task type", selection: Binding(
                        get: { selectedCreatedChartTaskTypeFilter },
                        set: { store.send(.createdChartTaskTypeFilterChanged($0)) }
                    )) {
                        ForEach(StatsTaskTypeFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                    .accessibilityIdentifier("stats.createdTasks.typePicker")

                    smallHighlightBadge(
                        title: "Created",
                        value: metrics.createdTotalCount.formatted()
                    )
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
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
                .chartYScale(domain: 0...metrics.createdChartUpperBound)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let count = value.as(Int.self) {
                                Text(count.formatted())
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: metrics.xAxisDates) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(chartPresentation.xAxisLabel(for: date))
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                }
                .frame(minWidth: chartPresentation.chartMinWidth, minHeight: 240)
                .padding(.top, 4)
            }
            .defaultScrollAnchor(.trailing)

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

    private func chartSection(metrics: Metrics) -> some View {
        StatsCompletionChartSection(
            subtitle: chartPresentation.chartSectionSubtitle(
                    totalCount: metrics.totalCount,
                    averagePerDay: metrics.averagePerDay,
                    dayCount: metrics.chartPoints.count
            ),
            peakValue: metrics.highlightedBusiestDay.map { "\($0.count)" } ?? "0",
            chartPoints: metrics.chartPoints,
            highlightedPoint: metrics.highlightedBusiestDay,
            averagePerDay: metrics.averagePerDay,
            chartUpperBound: metrics.chartUpperBound,
            xAxisDates: metrics.xAxisDates,
            highlightSymbolSize: selectedRange == .year ? 46 : 64,
            chartPresentation: chartPresentation,
            baseBarFill: baseBarFill,
            highlightBarFill: highlightBarFill,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme,
            insights: StatsChartInsightBuilder.completionInsights(
                metrics: metrics,
                selectedRange: selectedRange,
                chartPresentation: chartPresentation
            )
        )
    }

    private func focusChartSection(metrics: Metrics) -> some View {
        StatsFocusChartSection(
            subtitle: chartPresentation.focusChartSectionSubtitle(
                    totalFocusSeconds: metrics.totalFocusSeconds,
                    activeDayCount: metrics.focusActiveDayCount
            ),
            peakValue: metrics.highlightedFocusDay.map { chartPresentation.focusDurationText($0.seconds) } ?? "0m",
            focusChartPoints: metrics.focusChartPoints,
            highlightedFocusDay: metrics.highlightedFocusDay,
            averageFocusSecondsPerDay: metrics.averageFocusSecondsPerDay,
            focusChartUpperBound: metrics.focusChartUpperBound,
            xAxisDates: metrics.xAxisDates,
            chartPresentation: chartPresentation,
            highlightBarFill: highlightBarFill,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme,
            insights: StatsChartInsightBuilder.focusInsights(
                metrics: metrics,
                selectedRange: selectedRange,
                chartPresentation: chartPresentation
            )
        )
    }

    private func tagUsageSection(metrics: Metrics) -> some View {
        StatsTagUsageSection(
            points: metrics.tagUsagePoints,
            subtitle: chartPresentation.tagUsageSectionSubtitle(
                    points: metrics.tagUsagePoints,
                    periodDescription: selectedRange.periodDescription
            ),
            chartPresentation: chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private var activeItemsInfoButton: some View {
        Button {
            isActiveItemsInfoPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Show active items calculation")
        .accessibilityLabel("Show active items calculation")
        .popover(isPresented: $isActiveItemsInfoPresented, arrowEdge: .top) {
            StatsActiveItemsInfoPopover(breakdown: activeItemsBreakdown)
        }
    }

    private func smallHighlightBadge(title: String, value: String) -> some View {
        StatsSmallHighlightBadge(
            title: title,
            value: value,
            colorScheme: colorScheme,
            surfaceGradient: surfaceGradient
        )
    }

    private func rangeButtonSubtitle(for range: DoneChartRange) -> String {
        switch range {
        case .today:
            return "1 day"
        case .week:
            return "7 days"
        case .month:
            return "30 days"
        case .year:
            return "1 year"
        }
    }

    private var statsContentMaxWidth: CGFloat? {
        horizontalSizeClass == .regular ? 980 : nil
    }

    private var contentBottomPadding: CGFloat {
        36
    }

}
