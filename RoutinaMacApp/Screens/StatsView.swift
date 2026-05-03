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
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.04)
                ]
                : [
                    Color.white.opacity(0.98),
                    Color.white.opacity(0.88)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.accentColor.opacity(0.95),
                    Color.blue.opacity(0.7),
                    Color.black.opacity(0.92)
                ]
                : [
                    Color.accentColor.opacity(0.9),
                    Color.blue.opacity(0.6),
                    Color.white.opacity(0.96)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var pageBackground: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.black,
                    Color(red: 0.05, green: 0.07, blue: 0.11),
                    Color.black
                ]
                : [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color.white,
                    Color(red: 0.93, green: 0.96, blue: 0.99)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectorBackground: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.03)
                ]
                : [
                    Color.white.opacity(0.96),
                    Color.white.opacity(0.82)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectorActiveFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.95),
                Color.blue.opacity(0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var baseBarFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(colorScheme == .dark ? 0.75 : 0.6),
                Color.blue.opacity(colorScheme == .dark ? 0.55 : 0.45)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var createdBarFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.green.opacity(colorScheme == .dark ? 0.78 : 0.62),
                Color.mint.opacity(colorScheme == .dark ? 0.58 : 0.48)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var highlightBarFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.95),
                Color.yellow.opacity(0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
            periodDescription: userActivityPeriodDescription(metrics: metrics),
            chartPresentation: chartPresentation,
            colorScheme: colorScheme,
            heroGradient: heroGradient
        )
    }

    private func summaryCards(metrics: Metrics) -> some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: horizontalSizeClass == .compact ? 160 : 220,
                        maximum: 280
                    ),
                    spacing: 14
                )
            ],
            spacing: 14
        ) {
            if selectedRange != .today {
                summaryCard(
                    icon: "gauge.with.dots.needle.50percent",
                    accent: .mint,
                    title: "Daily average",
                    value: chartPresentation.averagePerDayText(for: metrics.averagePerDay),
                    caption: "Across \(metrics.chartPoints.count) days",
                    accessibilityIdentifier: "stats.summary.dailyAverage"
                )
            }

            summaryCard(
                icon: "timer",
                accent: .teal,
                title: "Focus time",
                value: chartPresentation.focusDurationText(metrics.totalFocusSeconds),
                caption: "\(metrics.focusActiveDayCount) focused \(metrics.focusActiveDayCount == 1 ? "day" : "days")",
                accessibilityIdentifier: "stats.summary.focusTime"
            )

            if selectedRange != .today {
                summaryCard(
                    icon: "stopwatch.fill",
                    accent: .purple,
                    title: "Focus average",
                    value: chartPresentation.focusDurationText(metrics.averageFocusSecondsPerDay),
                    caption: "Per day in this range",
                    accessibilityIdentifier: "stats.summary.focusAverage"
                )

                summaryCard(
                    icon: "bolt.fill",
                    accent: .orange,
                    title: "Best day",
                    value: metrics.highlightedBusiestDay.map { "\($0.count)" } ?? "0",
                    caption: metrics.highlightedBusiestDay.map { chartPresentation.bestDayCaption(for: $0) } ?? "No peak day yet",
                    accessibilityIdentifier: "stats.summary.bestDay"
                )
            }

            summaryCard(
                icon: "checkmark.seal.fill",
                accent: .blue,
                title: "Total dones",
                value: metrics.totalDoneCount.formatted(),
                caption: "All recorded completions",
                accessibilityIdentifier: "stats.summary.totalDones"
            )

            summaryCard(
                icon: "xmark.seal.fill",
                accent: .orange,
                title: "Total cancels",
                value: metrics.totalCanceledCount.formatted(),
                caption: "Canceled todos kept in timeline",
                accessibilityIdentifier: "stats.summary.totalCancels"
            )

            summaryCard(
                icon: "checklist.checked",
                accent: .green,
                title: activeItemsCardTitle,
                value: metrics.activeRoutineCount.formatted(),
                caption: activeRoutineCardCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.activeRoutines",
                showsActiveItemsInfo: true
            )

            summaryCard(
                icon: "archivebox.fill",
                accent: .teal,
                title: archivedItemsCardTitle,
                value: metrics.archivedRoutineCount.formatted(),
                caption: archivedRoutineCardCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.archivedRoutines"
            )
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
                insights: createdTasksChartInsights(metrics: metrics),
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }

    private var activeItemsCardTitle: String {
        switch selectedTaskTypeFilter {
        case .all:
            return "Active items"
        case .routines:
            return "Active routines"
        case .todos:
            return "Active todos"
        }
    }

    private var archivedItemsCardTitle: String {
        switch selectedTaskTypeFilter {
        case .all:
            return "Archived items"
        case .routines:
            return "Archived routines"
        case .todos:
            return "Archived todos"
        }
    }

    private func activeRoutineCardCaption(metrics: Metrics) -> String {
        if filteredTaskCount == 0 {
            switch selectedTaskTypeFilter {
            case .all:
                return "No items created yet"
            case .routines:
                return "No routines created yet"
            case .todos:
                return "No todos created yet"
            }
        }

        if metrics.activeRoutineCount == 0 {
            switch selectedTaskTypeFilter {
            case .all:
                return metrics.archivedRoutineCount == 1
                    ? "Your only item is archived"
                    : "All matching items are archived"
            case .routines:
                return metrics.archivedRoutineCount == 1
                    ? "Your only routine is paused"
                    : "All routines are currently paused"
            case .todos:
                return metrics.archivedRoutineCount == 1
                    ? "Your only todo is archived"
                    : "All todos are currently archived"
            }
        }

        if metrics.archivedRoutineCount == 0 {
            switch selectedTaskTypeFilter {
            case .all:
                return "Everything is currently active"
            case .routines:
                return "Everything is currently in rotation"
            case .todos:
                return "All matching todos are currently active"
            }
        }

        switch selectedTaskTypeFilter {
        case .all:
            return metrics.archivedRoutineCount == 1
                ? "1 archived item excluded"
                : "\(metrics.archivedRoutineCount) archived items excluded"
        case .routines:
            return metrics.archivedRoutineCount == 1
                ? "1 paused routine excluded"
                : "\(metrics.archivedRoutineCount) paused routines excluded"
        case .todos:
            return metrics.archivedRoutineCount == 1
                ? "1 archived todo excluded"
                : "\(metrics.archivedRoutineCount) archived todos excluded"
        }
    }

    private func archivedRoutineCardCaption(metrics: Metrics) -> String {
        if filteredTaskCount == 0 {
            switch selectedTaskTypeFilter {
            case .all:
                return "No items created yet"
            case .routines:
                return "No routines created yet"
            case .todos:
                return "No todos created yet"
            }
        }

        if metrics.archivedRoutineCount == 0 {
            switch selectedTaskTypeFilter {
            case .all:
                return "No archived items right now"
            case .routines:
                return "No archived routines right now"
            case .todos:
                return "No archived todos right now"
            }
        }

        switch selectedTaskTypeFilter {
        case .all:
            return metrics.archivedRoutineCount == 1
                ? "1 item is archived and hidden from Home"
                : "\(metrics.archivedRoutineCount) items are archived and hidden from Home"
        case .routines:
            return metrics.archivedRoutineCount == 1
                ? "1 routine is paused and hidden from Home"
                : "\(metrics.archivedRoutineCount) routines are paused and hidden from Home"
        case .todos:
            return metrics.archivedRoutineCount == 1
                ? "1 todo is archived and hidden from Home"
                : "\(metrics.archivedRoutineCount) todos are archived and hidden from Home"
        }
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
            insights: completionChartInsights(metrics: metrics)
        )
    }

    private func focusChartSection(metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Focus time per day",
                subtitle: chartPresentation.focusChartSectionSubtitle(
                    totalFocusSeconds: metrics.totalFocusSeconds,
                    activeDayCount: metrics.focusActiveDayCount
                )
            ) {
                smallHighlightBadge(
                    title: "Peak",
                    value: metrics.highlightedFocusDay.map { chartPresentation.focusDurationText($0.seconds) } ?? "0m"
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(metrics.focusChartPoints) { point in
                        let isHighlighted = point.date == metrics.highlightedFocusDay?.date

                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Minutes", point.minutes)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isHighlighted
                                ? AnyShapeStyle(highlightBarFill)
                                : AnyShapeStyle(StatsChartFill.focusBar(colorScheme: colorScheme))
                        )
                        .opacity(point.seconds == 0 ? 0.35 : 1)
                    }

                    if metrics.averageFocusSecondsPerDay > 0 {
                        RuleMark(y: .value("Average", metrics.averageFocusSecondsPerDay / 60))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .annotation(position: .topLeading, alignment: .leading) {
                                Text("Avg \(chartPresentation.focusDurationText(metrics.averageFocusSecondsPerDay))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(surfaceGradient, in: Capsule(style: .continuous))
                            }
                    }
                }
                .chartYScale(domain: 0...metrics.focusChartUpperBound)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text("\(Int(minutes.rounded()))m")
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
                insights: focusChartInsights(metrics: metrics),
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }

    private func tagUsageSection(metrics: Metrics) -> some View {
        let points = metrics.tagUsagePoints
        let maxValue = max(points.map(\.bubbleValue).max() ?? 1, 1)
        let columns = chartPresentation.tagUsageColumnCount(for: points.count)
        let rows = max(Int(ceil(Double(max(points.count, 1)) / Double(columns))), 1)

        return VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Tag usage",
                subtitle: chartPresentation.tagUsageSectionSubtitle(
                    points: metrics.tagUsagePoints,
                    periodDescription: selectedRange.periodDescription
                )
            ) {
                smallHighlightBadge(
                    title: "Tags",
                    value: points.count.formatted()
                )
            }

            if points.isEmpty {
                StatsEmptyChartStateView(
                    systemImage: "tag",
                    message: "Tags will appear here after matching routines are completed.",
                    colorScheme: colorScheme
                )
            } else {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        PointMark(
                            x: .value("Column", chartPresentation.tagUsageColumn(for: index, columns: columns)),
                            y: .value("Row", chartPresentation.tagUsageRow(for: index, columns: columns, rows: rows))
                        )
                        .symbolSize(chartPresentation.tagUsageSymbolSize(for: point, maxValue: maxValue))
                        .foregroundStyle(tagUsageBubbleColor(for: point))
                        .annotation(position: .overlay) {
                            VStack(spacing: 2) {
                                Text("#\(point.name)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)

                                Text(chartPresentation.tagUsageValueText(for: point))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                            }
                            .minimumScaleFactor(0.72)
                            .frame(width: chartPresentation.tagUsageLabelWidth(for: point, maxValue: maxValue))
                            .shadow(color: .black.opacity(0.22), radius: 1, x: 0, y: 1)
                        }
                    }
                }
                .chartXScale(domain: (-0.5)...(Double(columns) - 0.5))
                .chartYScale(domain: (-0.5)...(Double(rows) - 0.5))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                }
                .frame(minHeight: chartPresentation.tagUsageChartHeight(rows: rows))
                .accessibilityLabel("Tag usage bubble chart")
            }
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }

    private func summaryCard(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        caption: String,
        accessibilityIdentifier: String,
        showsActiveItemsInfo: Bool = false
    ) -> some View {
        StatsSummaryCard(
            icon: icon,
            accent: accent,
            title: title,
            value: value,
            caption: caption,
            accessibilityIdentifier: accessibilityIdentifier,
            colorScheme: colorScheme,
            surfaceGradient: surfaceGradient,
            accessibilityChildren: showsActiveItemsInfo ? .contain : .combine
        ) {
            if showsActiveItemsInfo {
                activeItemsInfoButton
            }
        }
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

    private func userActivityPeriodDescription(metrics: Metrics) -> String {
        if selectedRange == .year,
           metrics.chartPoints.count < selectedRange.trailingDayCount,
           let firstDate = metrics.chartPoints.first?.date {
            return "Since \(firstDate.formatted(.dateTime.month(.abbreviated).day().year()))"
        }
        return selectedRange.periodDescription
    }

    private func createdTasksChartInsights(metrics: Metrics) -> [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar.badge.plus",
                text: createdTasksPresentation.createdInPeriodInsight(totalCount: metrics.createdTotalCount)
            ),
            metrics.highlightedCreatedDay.map {
                StatsChartInsight(
                    systemImage: "star.fill",
                    text: "Most created: \(chartPresentation.bestDayCaption(for: $0))"
                )
            } ?? StatsChartInsight(
                systemImage: "plus.circle",
                text: createdTasksPresentation.waitingInsight
            )
        ]
    }

    private func completionChartInsights(metrics: Metrics) -> [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar",
                text: userActivityPeriodDescription(metrics: metrics)
            ),
            metrics.highlightedBusiestDay.map {
                StatsChartInsight(
                    systemImage: "star.fill",
                    text: "Best: \(chartPresentation.bestDayCaption(for: $0))"
                )
            } ?? StatsChartInsight(
                systemImage: "waveform.path.ecg",
                text: "Waiting for your first completion"
            )
        ]
    }

    private func focusChartInsights(metrics: Metrics) -> [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "calendar",
                text: userActivityPeriodDescription(metrics: metrics)
            ),
            metrics.highlightedFocusDay.map {
                StatsChartInsight(
                    systemImage: "timer",
                    text: "Best: \(chartPresentation.focusDurationText($0.seconds)) on \(chartPresentation.xAxisLabel(for: $0.date))"
                )
            } ?? StatsChartInsight(
                systemImage: "stopwatch",
                text: "Waiting for your first focus session"
            )
        ]
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

    private func tagUsageBubbleColor(for point: TagUsageChartPoint) -> Color {
        Color(routineTagHex: point.colorHex)
            ?? Color.accentColor.opacity(colorScheme == .dark ? 0.78 : 0.68)
    }

}
