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

    private struct ActiveItemsBreakdown {
        let routineCount: Int
        let todoCount: Int
        let openTodoCount: Int
        let completedTodoCount: Int
        let canceledTodoCount: Int
        let archivedCount: Int
        let activeCount: Int

        var matchingCount: Int {
            routineCount + todoCount
        }
    }

    private var selectedRange: DoneChartRange {
        store.selectedRange
    }

    private var selectedTaskTypeFilter: StatsTaskTypeFilter {
        store.taskTypeFilter
    }

    private var metrics: Metrics {
        store.metrics
    }

    private var filteredTaskCount: Int {
        store.filteredTaskCount
    }

    private var activeItemsBreakdown: ActiveItemsBreakdown {
        let now = Date()
        let filteredTasks = filteredTasksForCurrentStatsFilters
        let routineCount = filteredTasks.filter { !$0.isOneOffTask }.count
        let todoTasks = filteredTasks.filter(\.isOneOffTask)
        let archivedCount = filteredTasks.filter {
            $0.isArchived(referenceDate: now, calendar: calendar)
        }.count

        return ActiveItemsBreakdown(
            routineCount: routineCount,
            todoCount: todoTasks.count,
            openTodoCount: todoTasks.filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }.count,
            completedTodoCount: todoTasks.filter(\.isCompletedOneOff).count,
            canceledTodoCount: todoTasks.filter(\.isCanceledOneOff).count,
            archivedCount: archivedCount,
            activeCount: filteredTasks.count - archivedCount
        )
    }

    private var filteredTasksForCurrentStatsFilters: [RoutineTask] {
        let tasksMatchingTypeFilter = tasks.filter { task in
            switch selectedTaskTypeFilter {
            case .all:
                return true
            case .routines:
                return !task.isOneOffTask
            case .todos:
                return task.isOneOffTask
            }
        }

        let tasksMatchingMatrixFilter = tasksMatchingTypeFilter.filter { task in
            HomeFeature.matchesImportanceUrgencyFilter(
                store.selectedImportanceUrgencyFilter,
                importance: task.importance,
                urgency: task.urgency
            )
        }

        let includeFilteredTasks = tasksMatchingMatrixFilter.filter { task in
            HomeFeature.matchesSelectedTags(
                store.effectiveSelectedTags,
                mode: store.includeTagMatchMode,
                in: task.tags
            )
        }

        return includeFilteredTasks.filter { task in
            HomeFeature.matchesExcludedTags(
                store.excludedTags,
                mode: store.excludeTagMatchMode,
                in: task.tags
            )
        }
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
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection(metrics: metrics)
                        summaryCards(metrics: metrics)
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
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, contentBottomPadding)
                    .frame(maxWidth: statsContentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .background(pageBackground.ignoresSafeArea())
                .navigationTitle("Stats")
            }
            .task {
                store.send(.onAppear)
                store.send(.setData(tasks: tasks, logs: logs, focusSessions: focusSessions))
            }
            .onChange(of: tasks) { _, newValue in
                store.send(.setData(tasks: newValue, logs: logs, focusSessions: focusSessions))
            }
            .onChange(of: logs) { _, newValue in
                store.send(.setData(tasks: tasks, logs: newValue, focusSessions: focusSessions))
            }
            .onChange(of: focusSessions) { _, newValue in
                store.send(.setData(tasks: tasks, logs: logs, focusSessions: newValue))
            }
        }
    }

    private func heroSection(metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(rangeHeroLabel, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.62), in: Capsule())

                    Text(metrics.totalCount.formatted())
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(metrics.totalCount == 1 ? "completion logged" : "completions logged")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))

                    Text(userActivityPeriodDescription(metrics: metrics))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer(minLength: 0)

                if selectedRange != .today {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(metrics.activeDayCount)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)

                        Text(metrics.activeDayCount == 1 ? "active day" : "active days")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            if selectedRange != .today {
                sparklinePreview(metrics: metrics)

                HStack(spacing: 12) {
                    heroStatPill(
                        icon: "gauge.with.dots.needle.50percent",
                        title: "Daily avg",
                        value: chartPresentation.averagePerDayText(for: metrics.averagePerDay)
                    )

                    heroStatPill(
                        icon: "bolt.fill",
                        title: "Best day",
                        value: metrics.highlightedBusiestDay.map { "\($0.count)" } ?? "0"
                    )
                }
            }
        }
        .padding(22)
        .background(heroGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.08), radius: 22, y: 14)
    }

    private func sparklinePreview(metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily rhythm")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()

                Text(chartPresentation.sparklineCaption(highlightedBusiestDay: metrics.highlightedBusiestDay))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(metrics.sparklinePoints) { point in
                    Capsule(style: .continuous)
                        .fill(chartPresentation.sparklineColor(for: point, highlightedBusiestDay: metrics.highlightedBusiestDay))
                        .frame(maxWidth: .infinity)
                        .frame(height: chartPresentation.sparklineBarHeight(for: point, maxCount: metrics.sparklineMaxCount))
                }
            }
            .frame(height: 74, alignment: .bottom)
        }
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Completions per day")
                        .font(.title3.weight(.semibold))

                    Text(chartPresentation.chartSectionSubtitle(totalCount: metrics.totalCount, averagePerDay: metrics.averagePerDay, dayCount: metrics.chartPoints.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                smallHighlightBadge(
                    title: "Peak",
                    value: metrics.highlightedBusiestDay.map { "\($0.count)" } ?? "0"
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(metrics.chartPoints) { point in
                        let isHighlighted = point.date == metrics.highlightedBusiestDay?.date

                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Completions", point.count)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isHighlighted
                                ? AnyShapeStyle(highlightBarFill)
                                : AnyShapeStyle(baseBarFill)
                        )
                        .opacity(point.count == 0 ? 0.35 : 1)
                    }

                    if metrics.averagePerDay > 0 {
                        RuleMark(y: .value("Average", metrics.averagePerDay))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .annotation(position: .topLeading, alignment: .leading) {
                                Text("Avg \(chartPresentation.averagePerDayText(for: metrics.averagePerDay))")
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

                    if let highlightedBusiestDay = metrics.highlightedBusiestDay {
                        PointMark(
                            x: .value("Date", highlightedBusiestDay.date, unit: .day),
                            y: .value("Completions", highlightedBusiestDay.count)
                        )
                        .symbolSize(selectedRange == .year ? 46 : 64)
                        .foregroundStyle(Color.white)
                    }
                }
                .chartYScale(domain: 0...metrics.chartUpperBound)
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
                    plotArea
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04))
                        )
                }
                .frame(minWidth: chartPresentation.chartMinWidth, minHeight: 260)
                .padding(.top, 4)
            }
            .defaultScrollAnchor(.trailing)

            HStack(spacing: 10) {
                bottomInsightPill(
                    icon: "calendar",
                    text: userActivityPeriodDescription(metrics: metrics)
                )

                if let highlightedBusiestDay = metrics.highlightedBusiestDay {
                    bottomInsightPill(
                        icon: "star.fill",
                        text: "Best: \(chartPresentation.bestDayCaption(for: highlightedBusiestDay))"
                    )
                } else {
                    bottomInsightPill(
                        icon: "waveform.path.ecg",
                        text: "Waiting for your first completion"
                    )
                }
            }
        }
        .padding(20)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
        )
    }

    private func focusChartSection(metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus time per day")
                        .font(.title3.weight(.semibold))

                    Text(chartPresentation.focusChartSectionSubtitle(totalFocusSeconds: metrics.totalFocusSeconds, activeDayCount: metrics.focusActiveDayCount))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

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
                                : AnyShapeStyle(LinearGradient(
                                    colors: [
                                        Color.teal.opacity(colorScheme == .dark ? 0.78 : 0.64),
                                        Color.mint.opacity(colorScheme == .dark ? 0.6 : 0.5)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
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
                    plotArea
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04))
                        )
                }
                .frame(minWidth: chartPresentation.chartMinWidth, minHeight: 240)
                .padding(.top, 4)
            }
            .defaultScrollAnchor(.trailing)

            HStack(spacing: 10) {
                bottomInsightPill(icon: "calendar", text: userActivityPeriodDescription(metrics: metrics))

                if let focusDay = metrics.highlightedFocusDay {
                    bottomInsightPill(
                        icon: "timer",
                        text: "Best: \(chartPresentation.focusDurationText(focusDay.seconds)) on \(chartPresentation.xAxisLabel(for: focusDay.date))"
                    )
                } else {
                    bottomInsightPill(icon: "stopwatch", text: "Waiting for your first focus session")
                }
            }
        }
        .padding(20)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
        )
    }

    private func tagUsageSection(metrics: Metrics) -> some View {
        let points = metrics.tagUsagePoints
        let maxValue = max(points.map(\.bubbleValue).max() ?? 1, 1)
        let columns = chartPresentation.tagUsageColumnCount(for: points.count)
        let rows = max(Int(ceil(Double(max(points.count, 1)) / Double(columns))), 1)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tag usage")
                        .font(.title3.weight(.semibold))

                    Text(chartPresentation.tagUsageSectionSubtitle(points: metrics.tagUsagePoints, periodDescription: selectedRange.periodDescription))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                smallHighlightBadge(
                    title: "Tags",
                    value: points.count.formatted()
                )
            }

            if points.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tag")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Tags will appear here after matching routines are completed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04))
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
                    plotArea
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04))
                        )
                }
                .frame(minHeight: chartPresentation.tagUsageChartHeight(rows: rows))
                .accessibilityLabel("Tag usage bubble chart")
            }
        }
        .padding(20)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
        )
    }

    private func heroStatPill(icon: String, title: String, value: String) -> some View {
        StatsHeroStatPill(icon: icon, title: title, value: value, colorScheme: colorScheme)
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
            activeItemsInfoPopover
        }
    }

    private var activeItemsInfoPopover: some View {
        let breakdown = activeItemsBreakdown

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Active items")
                    .font(.headline.weight(.semibold))

                Text("Calculated from the items matching the current Stats filters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                formulaRow(
                    title: "Matching items",
                    formula: "\(breakdown.routineCount.formatted()) routines + \(breakdown.todoCount.formatted()) todos",
                    result: breakdown.matchingCount.formatted()
                )

                formulaRow(
                    title: "Active items",
                    formula: "\(breakdown.matchingCount.formatted()) matching - \(breakdown.archivedCount.formatted()) archived",
                    result: breakdown.activeCount.formatted()
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Todo breakdown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(breakdown.openTodoCount.formatted()) open + \(breakdown.completedTodoCount.formatted()) completed + \(breakdown.canceledTodoCount.formatted()) canceled = \(breakdown.todoCount.formatted()) todos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }

    private func formulaRow(title: String, formula: String, result: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Text(result)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }

            Text(formula)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private func bottomInsightPill(icon: String, text: String) -> some View {
        StatsBottomInsightPill(icon: icon, text: text, colorScheme: colorScheme)
    }

    private var rangeHeroLabel: String {
        switch selectedRange {
        case .today:
            return "Today"
        case .week:
            return "This week"
        case .month:
            return "This month"
        case .year:
            return "This year"
        }
    }

    private func userActivityPeriodDescription(metrics: Metrics) -> String {
        if selectedRange == .year,
           metrics.chartPoints.count < selectedRange.trailingDayCount,
           let firstDate = metrics.chartPoints.first?.date {
            return "Since \(firstDate.formatted(.dateTime.month(.abbreviated).day().year()))"
        }
        return selectedRange.periodDescription
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
