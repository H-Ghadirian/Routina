import ComposableArchitecture
import SwiftData
import SwiftUI

struct StatsViewWrapper: View {
    let store: StoreOf<StatsFeature>

    var body: some View {
        StatsView(store: store)
            .background {
                StatsDataObserver(store: store)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
    }
}

private struct StatsDataObserver: View {
    let store: StoreOf<StatsFeature>
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Color.clear
            .task {
                store.send(.onAppear)
                refreshData()
            }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                refreshData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
                refreshData()
            }
    }

    private func refreshData() {
        do {
            let tasks = try modelContext.fetch(FetchDescriptor<RoutineTask>())
            let logs = try modelContext.fetch(FetchDescriptor<RoutineLog>())
            let focusSessions = try modelContext.fetch(FetchDescriptor<FocusSession>())
            store.send(.setData(tasks: tasks, logs: logs, focusSessions: focusSessions))
        } catch {
            NSLog("StatsDataObserver: failed to refresh stats data - \(error)")
        }
    }
}

struct StatsView: View {
    let store: StoreOf<StatsFeature>
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isActiveItemsInfoPresented = false
    @State private var isEditingDashboard = false
    @State private var isAddDashboardItemSheetPresented = false
    @AppStorage(UserDefaultStringValueKey.appSettingMacStatsDashboardHiddenItemIDs.rawValue, store: SharedDefaults.app)
    private var hiddenDashboardItemIDsRaw = ""

    private typealias Metrics = StatsFeature.Metrics

    private struct DashboardSnapshot {
        let selectedRange: DoneChartRange
        let selectedTaskTypeFilter: StatsTaskTypeFilter
        let selectedCreatedChartTaskTypeFilter: StatsTaskTypeFilter
        let metrics: Metrics
        let filteredTaskCount: Int
        let isGitFeaturesEnabled: Bool
        let gitHubConnection: GitHubConnectionStatus
        let gitHubStats: GitHubStatsSnapshot?
        let isGitHubStatsLoading: Bool
        let gitHubStatsErrorMessage: String?
        let chartPresentation: StatsChartPresentation
        let createdTasksPresentation: StatsCreatedTasksPresentation
    }

    private var dashboardSnapshot: DashboardSnapshot {
        let selectedRange = store.selectedRange
        let selectedCreatedChartTaskTypeFilter = store.createdChartTaskTypeFilter
        let chartPresentation = StatsChartPresentation(
            selectedRange: selectedRange,
            isCompact: horizontalSizeClass == .compact
        )

        return DashboardSnapshot(
            selectedRange: selectedRange,
            selectedTaskTypeFilter: store.taskTypeFilter,
            selectedCreatedChartTaskTypeFilter: selectedCreatedChartTaskTypeFilter,
            metrics: store.metrics,
            filteredTaskCount: store.filteredTaskCount,
            isGitFeaturesEnabled: store.isGitFeaturesEnabled,
            gitHubConnection: store.gitHubConnection,
            gitHubStats: store.gitHubStats,
            isGitHubStatsLoading: store.isGitHubStatsLoading,
            gitHubStatsErrorMessage: store.gitHubStatsErrorMessage,
            chartPresentation: chartPresentation,
            createdTasksPresentation: StatsCreatedTasksPresentation(
                taskTypeFilter: selectedCreatedChartTaskTypeFilter,
                selectedRange: selectedRange
            )
        )
    }

    private var selectedRange: DoneChartRange {
        store.selectedRange
    }

    private var selectedTaskTypeFilter: StatsTaskTypeFilter {
        store.taskTypeFilter
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
        .filteredTasks(from: store.tasks)
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

    private var hiddenDashboardItemIDs: Set<String> {
        Set(
            hiddenDashboardItemIDsRaw
                .split(separator: ",")
                .map(String.init)
        )
    }

    private var availableDashboardItems: [StatsMacDashboardItem] {
        StatsMacDashboardItem.allCases.filter { item in
            item.isAvailable(
                selectedRange: selectedRange,
                isGitFeaturesEnabled: store.isGitFeaturesEnabled
            )
        }
    }

    private var hiddenAvailableDashboardItems: [StatsMacDashboardItem] {
        availableDashboardItems.filter { hiddenDashboardItemIDs.contains($0.rawValue) }
    }

    var body: some View {
        WithPerceptionTracking {
            dashboardBody(snapshot: dashboardSnapshot)
        }
    }

    private func dashboardBody(snapshot: DashboardSnapshot) -> some View {
        NavigationStack {
            StatsDashboardScrollContainer(
                pageBackground: pageBackground,
                bottomPadding: contentBottomPadding,
                maxContentWidth: statsContentMaxWidth
            ) {
                VStack(alignment: .leading, spacing: 24) {
                    if isEditingDashboard {
                        dashboardEditControls
                    }

                    if isDashboardItemVisible(.hero) {
                        editableDashboardSection(.hero) {
                            heroSection(snapshot: snapshot)
                        }
                    }

                    summaryCards(snapshot: snapshot)

                    if isDashboardItemVisible(.createdTasksChart) {
                        editableDashboardSection(.createdTasksChart) {
                            createdTasksChartSection(snapshot: snapshot)
                        }
                    }

                    if snapshot.selectedRange != .today, isDashboardItemVisible(.completionChart) {
                        editableDashboardSection(.completionChart) {
                            chartSection(snapshot: snapshot)
                        }
                    }

                    if isDashboardItemVisible(.tagUsage) {
                        editableDashboardSection(.tagUsage) {
                            tagUsageSection(snapshot: snapshot)
                        }
                    }

                    if snapshot.selectedRange != .today, isDashboardItemVisible(.focusChart) {
                        editableDashboardSection(.focusChart) {
                            focusChartSection(snapshot: snapshot)
                        }
                    }

                    if snapshot.isGitFeaturesEnabled, isDashboardItemVisible(.gitHub) {
                        editableDashboardSection(.gitHub) {
                            gitHubSection(snapshot: snapshot)
                        }
                    }
                }
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    dashboardEditButton
                }
            }
        }
        .sheet(isPresented: $isAddDashboardItemSheetPresented) {
            addDashboardItemSheet
        }
    }

    private func heroSection(snapshot: DashboardSnapshot) -> some View {
        let metrics = snapshot.metrics

        return StatsHeroSectionView(
            selectedRange: snapshot.selectedRange,
            totalCount: metrics.totalCount,
            activeDayCount: metrics.activeDayCount,
            averagePerDay: metrics.averagePerDay,
            highlightedBusiestDay: metrics.highlightedBusiestDay,
            sparklinePoints: metrics.sparklinePoints,
            sparklineMaxCount: metrics.sparklineMaxCount,
            periodDescription: StatsChartInsightBuilder.userActivityPeriodDescription(
                selectedRange: snapshot.selectedRange,
                chartPoints: metrics.chartPoints
            ),
            chartPresentation: snapshot.chartPresentation,
            colorScheme: colorScheme,
            heroGradient: heroGradient
        )
    }

    private func summaryCards(snapshot: DashboardSnapshot) -> some View {
        let items = visibleSummaryCardItems(
            StatsSummaryCardItemBuilder.items(
                metrics: snapshot.metrics,
                selectedRange: snapshot.selectedRange,
                chartPresentation: snapshot.chartPresentation,
                taskTypeFilter: snapshot.selectedTaskTypeFilter,
                filteredTaskCount: snapshot.filteredTaskCount,
                showsActiveAccessory: true
            )
        )

        return LazyVGrid(
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
            ForEach(items) { item in
                editableDashboardSection(dashboardItem(for: item)) {
                    StatsSummaryCard(
                        icon: item.icon,
                        accent: item.accent,
                        title: item.title,
                        value: item.value,
                        caption: item.caption,
                        accessibilityIdentifier: item.accessibilityIdentifier,
                        colorScheme: colorScheme,
                        surfaceGradient: surfaceGradient,
                        accessibilityChildren: item.showsAccessory ? .contain : .combine
                    ) {
                        Group {
                            if item.showsAccessory {
                                activeItemsInfoButton
                            }
                        }
                    }
                }
            }
        }
    }

    private var dashboardEditButton: some View {
        Button(isEditingDashboard ? "Done" : "Edit") {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isEditingDashboard.toggle()
            }
        }
        .help(isEditingDashboard ? "Finish editing stats dashboard" : "Edit stats dashboard")
        .accessibilityLabel(isEditingDashboard ? "Finish editing stats dashboard" : "Edit stats dashboard")
    }

    private var dashboardEditControls: some View {
        HStack(spacing: 12) {
            Button {
                isAddDashboardItemSheetPresented = true
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(hiddenAvailableDashboardItems.isEmpty)
            .accessibilityLabel("Add stats item")

            Button {
                showAllDashboardItems()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .disabled(hiddenDashboardItemIDs.isEmpty)
            .accessibilityLabel("Reset stats dashboard")
        }
    }

    private var addDashboardItemSheet: some View {
        NavigationStack {
            List {
                if hiddenAvailableDashboardItems.isEmpty {
                    ContentUnavailableView(
                        "All items are visible",
                        systemImage: "checkmark.circle",
                        description: Text("Remove a stats item to add it back here.")
                    )
                } else {
                    Section("Hidden items") {
                        ForEach(hiddenAvailableDashboardItems) { item in
                            Button {
                                addDashboardItem(item)
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .foregroundStyle(.primary)

                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: item.systemImage)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(item.title)")
                        }
                    }
                }
            }
            .frame(minWidth: 360, minHeight: 320)
            .navigationTitle("Add to Stats")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isAddDashboardItemSheetPresented = false
                    }
                }
            }
        }
    }

    private func gitHubSection(snapshot: DashboardSnapshot) -> some View {
        StatsMacGitHubSection(
            connection: snapshot.gitHubConnection,
            stats: snapshot.gitHubStats,
            errorMessage: snapshot.gitHubStatsErrorMessage,
            isLoading: snapshot.isGitHubStatsLoading,
            selectedRange: snapshot.selectedRange,
            horizontalSizeClass: horizontalSizeClass,
            colorScheme: colorScheme,
            calendar: calendar,
            onRefresh: { store.send(.gitHubStatsRefreshRequested) }
        )
    }

    private func createdTasksChartSection(snapshot: DashboardSnapshot) -> some View {
        StatsCreatedTasksChartSection(
            metrics: snapshot.metrics,
            selectedRange: snapshot.selectedRange,
            selectedTaskTypeFilter: snapshot.selectedCreatedChartTaskTypeFilter,
            chartPresentation: snapshot.chartPresentation,
            createdTasksPresentation: snapshot.createdTasksPresentation,
            createdBarFill: createdBarFill,
            highlightBarFill: highlightBarFill,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme,
            onSelectTaskTypeFilter: { store.send(.createdChartTaskTypeFilterChanged($0)) }
        )
    }

    private func chartSection(snapshot: DashboardSnapshot) -> some View {
        let metrics = snapshot.metrics

        return StatsCompletionChartSection(
            subtitle: snapshot.chartPresentation.chartSectionSubtitle(
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
            highlightSymbolSize: snapshot.selectedRange == .year ? 46 : 64,
            chartPresentation: snapshot.chartPresentation,
            baseBarFill: baseBarFill,
            highlightBarFill: highlightBarFill,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme,
            insights: StatsChartInsightBuilder.completionInsights(
                metrics: metrics,
                selectedRange: snapshot.selectedRange,
                chartPresentation: snapshot.chartPresentation
            )
        )
    }

    private func focusChartSection(snapshot: DashboardSnapshot) -> some View {
        let metrics = snapshot.metrics

        return StatsFocusChartSection(
            subtitle: snapshot.chartPresentation.focusChartSectionSubtitle(
                    totalFocusSeconds: metrics.totalFocusSeconds,
                    activeDayCount: metrics.focusActiveDayCount
            ),
            peakValue: metrics.highlightedFocusDay.map { snapshot.chartPresentation.focusDurationText($0.seconds) } ?? "0m",
            focusChartPoints: metrics.focusChartPoints,
            highlightedFocusDay: metrics.highlightedFocusDay,
            averageFocusSecondsPerDay: metrics.averageFocusSecondsPerDay,
            focusChartUpperBound: metrics.focusChartUpperBound,
            xAxisDates: metrics.xAxisDates,
            chartPresentation: snapshot.chartPresentation,
            highlightBarFill: highlightBarFill,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme,
            insights: StatsChartInsightBuilder.focusInsights(
                metrics: metrics,
                selectedRange: snapshot.selectedRange,
                chartPresentation: snapshot.chartPresentation
            )
        )
    }

    private func tagUsageSection(snapshot: DashboardSnapshot) -> some View {
        let metrics = snapshot.metrics

        return StatsTagUsageSection(
            points: metrics.tagUsagePoints,
            subtitle: snapshot.chartPresentation.tagUsageSectionSubtitle(
                    points: metrics.tagUsagePoints,
                    periodDescription: snapshot.selectedRange.periodDescription
            ),
            chartPresentation: snapshot.chartPresentation,
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

    private func isDashboardItemVisible(_ item: StatsMacDashboardItem) -> Bool {
        !hiddenDashboardItemIDs.contains(item.rawValue)
    }

    private func visibleSummaryCardItems(_ items: [StatsSummaryCardItem]) -> [StatsSummaryCardItem] {
        items.filter { item in
            isDashboardItemVisible(dashboardItem(for: item))
        }
    }

    private func dashboardItem(for item: StatsSummaryCardItem) -> StatsMacDashboardItem {
        StatsMacDashboardItem(summaryAccessibilityIdentifier: item.accessibilityIdentifier)
    }

    private func removeDashboardItem(_ item: StatsMacDashboardItem) {
        var hiddenIDs = hiddenDashboardItemIDs
        hiddenIDs.insert(item.rawValue)
        setHiddenDashboardItemIDs(hiddenIDs)
    }

    private func addDashboardItem(_ item: StatsMacDashboardItem) {
        var hiddenIDs = hiddenDashboardItemIDs
        hiddenIDs.remove(item.rawValue)
        setHiddenDashboardItemIDs(hiddenIDs)

        if hiddenAvailableDashboardItems.isEmpty {
            isAddDashboardItemSheetPresented = false
        }
    }

    private func showAllDashboardItems() {
        setHiddenDashboardItemIDs([])
    }

    private func setHiddenDashboardItemIDs(_ itemIDs: Set<String>) {
        let rawValue = itemIDs.sorted().joined(separator: ",")
        CloudSettingsKeyValueSync.setString(
            rawValue.isEmpty ? nil : rawValue,
            for: .appSettingMacStatsDashboardHiddenItemIDs
        )
    }

    private func editableDashboardSection<Content: View>(
        _ item: StatsMacDashboardItem,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Group {
            if isEditingDashboard {
                ZStack(alignment: .topLeading) {
                    content()
                        .opacity(0.96)

                Button {
                    removeDashboardItem(item)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                }
                .buttonStyle(.plain)
                .offset(x: -7, y: -10)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Remove \(item.title)")
                }
            } else {
                content()
            }
        }
    }
}

private enum StatsMacDashboardItem: String, CaseIterable, Identifiable {
    case hero
    case dailyAverage
    case focusTime
    case focusAverage
    case bestDay
    case totalDones
    case totalCancels
    case activeItems
    case archivedItems
    case createdTasksChart
    case completionChart
    case tagUsage
    case focusChart
    case gitHub

    var id: String { rawValue }

    init(summaryAccessibilityIdentifier: String) {
        switch summaryAccessibilityIdentifier {
        case "stats.summary.dailyAverage":
            self = .dailyAverage
        case "stats.summary.focusTime":
            self = .focusTime
        case "stats.summary.focusAverage":
            self = .focusAverage
        case "stats.summary.bestDay":
            self = .bestDay
        case "stats.summary.totalDones":
            self = .totalDones
        case "stats.summary.totalCancels":
            self = .totalCancels
        case "stats.summary.activeRoutines":
            self = .activeItems
        case "stats.summary.archivedRoutines":
            self = .archivedItems
        default:
            self = .hero
        }
    }

    var title: String {
        switch self {
        case .hero:
            return "Activity overview"
        case .dailyAverage:
            return "Daily average"
        case .focusTime:
            return "Focus time"
        case .focusAverage:
            return "Focus average"
        case .bestDay:
            return "Best day"
        case .totalDones:
            return "Total dones"
        case .totalCancels:
            return "Total cancels"
        case .activeItems:
            return "Active items"
        case .archivedItems:
            return "Archived items"
        case .createdTasksChart:
            return "Tasks created chart"
        case .completionChart:
            return "Completions chart"
        case .tagUsage:
            return "Tag usage"
        case .focusChart:
            return "Focus chart"
        case .gitHub:
            return "GitHub stats"
        }
    }

    var subtitle: String {
        switch self {
        case .hero:
            return "The large stats summary at the top of the screen."
        case .dailyAverage, .focusTime, .focusAverage, .bestDay, .totalDones, .totalCancels, .activeItems, .archivedItems:
            return "A compact stats card in the summary grid."
        case .createdTasksChart:
            return "A bar chart of routines and todos created over time."
        case .completionChart:
            return "A bar chart of completed routines over time."
        case .tagUsage:
            return "A bubble chart of tag activity."
        case .focusChart:
            return "A bar chart of focus time over time."
        case .gitHub:
            return "Contribution and repository activity."
        }
    }

    var systemImage: String {
        switch self {
        case .hero:
            return "chart.line.uptrend.xyaxis"
        case .dailyAverage:
            return "gauge.with.dots.needle.50percent"
        case .focusTime:
            return "timer"
        case .focusAverage:
            return "stopwatch.fill"
        case .bestDay:
            return "bolt.fill"
        case .totalDones:
            return "checkmark.seal.fill"
        case .totalCancels:
            return "xmark.seal.fill"
        case .activeItems:
            return "checklist.checked"
        case .archivedItems:
            return "archivebox.fill"
        case .createdTasksChart:
            return "plus.forwardslash.minus"
        case .completionChart:
            return "chart.bar.xaxis"
        case .tagUsage:
            return "tag.fill"
        case .focusChart:
            return "chart.xyaxis.line"
        case .gitHub:
            return "chevron.left.forwardslash.chevron.right"
        }
    }

    func isAvailable(
        selectedRange: DoneChartRange,
        isGitFeaturesEnabled: Bool
    ) -> Bool {
        switch self {
        case .dailyAverage, .focusAverage, .bestDay, .completionChart, .focusChart:
            return selectedRange != .today
        case .gitHub:
            return isGitFeaturesEnabled
        default:
            return true
        }
    }
}
