import ComposableArchitecture
import SwiftData
import SwiftUI

struct StatsViewWrapper: View {
    let store: StoreOf<StatsFeature>
    @Binding var selectedDashboardScope: StatsDashboardScope
    var showsFocusTimerToolbarItem = true

    var body: some View {
        StatsView(
            store: store,
            selectedDashboardScope: $selectedDashboardScope,
            showsFocusTimerToolbarItem: showsFocusTimerToolbarItem
        )
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
    @AppStorage(UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue, store: SharedDefaults.app)
    private var isPlacesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue, store: SharedDefaults.app)
    private var isNotesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue, store: SharedDefaults.app)
    private var isAwayEnabled = false

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
            .onChange(of: isPlacesEnabled) { _, _ in
                refreshData()
            }
            .onChange(of: isNotesEnabled) { _, _ in
                refreshData()
            }
            .onChange(of: isAwayEnabled) { _, _ in
                refreshData()
            }
    }

    private func refreshData() {
        do {
            let tasks = try modelContext.fetch(FetchDescriptor<RoutineTask>())
            let logs = try modelContext.fetch(FetchDescriptor<RoutineLog>())
            let focusSessions = try modelContext.fetch(FetchDescriptor<FocusSession>())
            let sprintFocusSessions = try modelContext.fetch(FetchDescriptor<SprintFocusSessionRecord>())
            let boardSprints = try modelContext.fetch(FetchDescriptor<BoardSprintRecord>())
            let sleepSessions = try modelContext.fetch(FetchDescriptor<SleepSession>())
            let awaySessions = try modelContext.fetch(FetchDescriptor<AwaySession>())
            let emotionLogs = try modelContext.fetch(FetchDescriptor<EmotionLog>())
            let notes = try modelContext.fetch(FetchDescriptor<RoutineNote>())
            let events = try modelContext.fetch(FetchDescriptor<RoutineEvent>())
            let noteAttachments = try modelContext.fetch(FetchDescriptor<RoutineNoteAttachment>())
            let goals = try modelContext.fetch(FetchDescriptor<RoutineGoal>())
            let places = try modelContext.fetch(FetchDescriptor<RoutinePlace>())
            let placeCheckInSessions = try modelContext.fetch(FetchDescriptor<PlaceCheckInSession>())
            store.send(
                .setData(
                    tasks: tasks,
                    logs: logs,
                    focusSessions: focusSessions,
                    sprintFocusSessions: sprintFocusSessions,
                    boardSprints: boardSprints,
                    sleepSessions: isAwayEnabled ? sleepSessions : [],
                    awaySessions: isAwayEnabled ? awaySessions : [],
                    emotionLogs: emotionLogs,
                    notes: isNotesEnabled ? notes : [],
                    events: events,
                    noteAttachmentNoteIDs: isNotesEnabled ? Set(noteAttachments.map(\.noteID)) : [],
                    goals: goals,
                    places: isPlacesEnabled ? places : [],
                    placeCheckInSessions: isPlacesEnabled ? placeCheckInSessions : []
                )
            )
        } catch {
            NSLog("StatsDataObserver: failed to refresh stats data - \(error)")
        }
    }
}

struct StatsView: View {
    let store: StoreOf<StatsFeature>
    @Binding var selectedDashboardScope: StatsDashboardScope
    var showsFocusTimerToolbarItem = true
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isActiveItemsInfoPresented = false
    @State private var isEditingDashboard = false
    @State private var isAddDashboardItemSheetPresented = false
    @State private var draggedDashboardItemID: String?
    @AppStorage(UserDefaultStringValueKey.appSettingMacStatsDashboardHiddenItemIDs.rawValue, store: SharedDefaults.app)
    private var hiddenDashboardItemIDsRaw = StatsMacDashboardItem.defaultHiddenItemIDsRawValue
    @AppStorage(UserDefaultStringValueKey.appSettingMacStatsDashboardItemOrderIDs.rawValue, store: SharedDefaults.app)
    private var dashboardItemOrderIDsRaw = ""
    @AppStorage(UserDefaultStringValueKey.appSettingMacStatsSummaryDisplayMode.rawValue, store: SharedDefaults.app)
    private var summaryDisplayModeRaw = StatsSummaryDisplayMode.cards.rawValue
    @AppStorage(UserDefaultBoolValueKey.appSettingStatsWinsEnabled.rawValue, store: SharedDefaults.app)
    private var isStatsWinsEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingStatsSleepTabEnabled.rawValue, store: SharedDefaults.app)
    private var isStatsSleepTabEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingStatsAchievementsEnabled.rawValue, store: SharedDefaults.app)
    private var isStatsAchievementsEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue, store: SharedDefaults.app)
    private var isGoalsTabEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue, store: SharedDefaults.app)
    private var areMacEventEmotionActionsEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue, store: SharedDefaults.app)
    private var isPlacesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue, store: SharedDefaults.app)
    private var isNotesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue, store: SharedDefaults.app)
    private var isAwayEnabled = false

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

    private var statsPlaces: [RoutinePlace] {
        isPlacesEnabled ? store.places : []
    }

    private var statsPlaceCheckInSessions: [PlaceCheckInSession] {
        isPlacesEnabled ? store.placeCheckInSessions : []
    }

    private var statsSleepSessions: [SleepSession] {
        isAwayEnabled ? store.sleepSessions : []
    }

    private var statsAwaySessions: [AwaySession] {
        isAwayEnabled ? store.awaySessions : []
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
            (item != .notes || isNotesEnabled)
                && (item != .awayTime || isAwayEnabled)
                && (item != .sleepTime || isAwayEnabled)
                && (item != .sleepSessions || isAwayEnabled)
                && item.isAvailable(
                    selectedRange: selectedRange,
                    isGitFeaturesEnabled: store.isGitFeaturesEnabled,
                    isGoalsTabEnabled: isGoalsTabEnabled,
                    areMacEventEmotionActionsEnabled: areMacEventEmotionActionsEnabled,
                    isStatsWinsEnabled: isStatsWinsEnabled,
                    isStatsAchievementsEnabled: isStatsAchievementsEnabled
                )
                && item.isReportable(metrics: store.metrics)
        }
    }

    private var orderedAvailableDashboardItems: [StatsMacDashboardItem] {
        StatsDashboardOrderSupport.orderedItems(
            availableDashboardItems,
            storedRawValue: dashboardItemOrderIDsRaw
        )
    }

    private var visibleOrderedDashboardItems: [StatsMacDashboardItem] {
        orderedAvailableDashboardItems.filter(isDashboardItemVisible)
    }

    private var scopedVisibleOrderedDashboardItems: [StatsMacDashboardItem] {
        visibleOrderedDashboardItems.filter { $0.isIncluded(in: effectiveDashboardScope) }
    }

    private var hiddenAvailableDashboardItems: [StatsMacDashboardItem] {
        orderedAvailableDashboardItems.filter { hiddenDashboardItemIDs.contains($0.rawValue) }
    }

    private var effectiveDashboardScope: StatsDashboardScope {
        if selectedDashboardScope == .wins && !isStatsWinsEnabled {
            return .all
        }
        if selectedDashboardScope == .sleep && (!isAwayEnabled || !isStatsSleepTabEnabled) {
            return .all
        }
        if selectedDashboardScope == .achievements && !isStatsAchievementsEnabled {
            return .all
        }
        return selectedDashboardScope
    }

    private var summaryDisplayMode: StatsSummaryDisplayMode {
        StatsSummaryDisplayMode(rawValue: summaryDisplayModeRaw) ?? .cards
    }

    private var summaryDisplayModeBinding: Binding<StatsSummaryDisplayMode> {
        Binding(
            get: { summaryDisplayMode },
            set: { mode in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    CloudSettingsKeyValueSync.setString(
                        mode.rawValue,
                        for: .appSettingMacStatsSummaryDisplayMode
                    )
                }
            }
        )
    }

    var body: some View {
        dashboardBody(snapshot: dashboardSnapshot)
    }

    private func dashboardBody(snapshot: DashboardSnapshot) -> some View {
        NavigationStack {
            StatsDashboardScrollContainer(
                pageBackground: pageBackground,
                bottomPadding: contentBottomPadding,
                maxContentWidth: nil
            ) {
                let blocks = dashboardBlocks(snapshot: snapshot)
                VStack(alignment: .leading, spacing: 24) {
                    if isEditingDashboard {
                        dashboardEditControls
                    }

                    if blocks.isEmpty {
                        StatsEmptyDashboardStateView(
                            hasActiveFilters: store.hasActiveFilters,
                            colorScheme: colorScheme
                        )
                    } else {
                        ForEach(blocks) { block in
                            dashboardBlockView(block, snapshot: snapshot)
                        }
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                if showsFocusTimerToolbarItem {
                    RoutinaMacFocusTimerToolbarItem()
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    summaryDisplayModeMenu
                    dashboardEditButton
                }
            }
        }
        .sheet(isPresented: $isAddDashboardItemSheetPresented) {
            addDashboardItemSheet
        }
    }

    private func dashboardBlocks(snapshot: DashboardSnapshot) -> [StatsMacDashboardBlock] {
        var blocks: [StatsMacDashboardBlock] = []
        var pendingSummaryItems: [StatsMacDashboardItem] = []

        func flushSummaryItems() {
            guard !pendingSummaryItems.isEmpty else { return }
            blocks.append(.summaryCards(pendingSummaryItems))
            pendingSummaryItems.removeAll()
        }

        for item in scopedVisibleOrderedDashboardItems {
            if item.isSummaryCard {
                pendingSummaryItems.append(item)
            } else {
                flushSummaryItems()
                blocks.append(.section(item))
            }
        }

        flushSummaryItems()
        return blocks.filter { block in
            switch block {
            case .section:
                return true
            case let .summaryCards(items):
                return !summaryCardItems(snapshot: snapshot, orderedBy: items).isEmpty
            }
        }
    }

    @ViewBuilder
    private func dashboardBlockView(_ block: StatsMacDashboardBlock, snapshot: DashboardSnapshot) -> some View {
        switch block {
        case let .section(item):
            dashboardSection(item, snapshot: snapshot)
        case let .summaryCards(items):
            summaryCards(snapshot: snapshot, dashboardItems: items)
        }
    }

    @ViewBuilder
    private func dashboardSection(_ item: StatsMacDashboardItem, snapshot: DashboardSnapshot) -> some View {
        switch item {
        case .hero:
            editableDashboardSection(.hero) {
                heroSection(snapshot: snapshot)
            }
        case .unassignedFocus:
            editableDashboardSection(.unassignedFocus) {
                UnassignedFocusSessionsCard(focusSessions: store.focusSessions)
            }
        case .createdTasksChart:
            editableDashboardSection(.createdTasksChart) {
                createdTasksChartSection(snapshot: snapshot)
            }
        case .completionChart:
            editableDashboardSection(.completionChart) {
                chartSection(snapshot: snapshot)
            }
        case .hourlyActivity:
            editableDashboardSection(.hourlyActivity) {
                hourlyActivitySection(snapshot: snapshot)
            }
        case .tagUsage:
            editableDashboardSection(.tagUsage) {
                tagUsageSection(snapshot: snapshot)
            }
        case .focusChart:
            editableDashboardSection(.focusChart) {
                focusChartSection(snapshot: snapshot)
            }
        case .focus2048:
            editableDashboardSection(.focus2048) {
                focus2048Section(snapshot: snapshot)
            }
        case .recentWins:
            editableDashboardSection(.recentWins) {
                recentWinsSection()
            }
        case .focusAchievements:
            editableDashboardSection(.focusAchievements) {
                achievementsSection()
            }
        case .focusWorkChart:
            editableDashboardSection(.focusWorkChart) {
                focusWorkChartSection(snapshot: snapshot)
            }
        case .estimateActual:
            editableDashboardSection(.estimateActual) {
                estimateActualChartSection(snapshot: snapshot)
            }
        case .goalProgress:
            editableDashboardSection(.goalProgress) {
                goalProgressSection(snapshot: snapshot)
            }
        case .emotionTrend:
            editableDashboardSection(.emotionTrend) {
                emotionTrendSection(snapshot: snapshot)
            }
        case .gitHub:
            editableDashboardSection(.gitHub) {
                gitHubSection(snapshot: snapshot)
            }
        default:
            EmptyView()
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

    @ViewBuilder
    private func summaryCards(
        snapshot: DashboardSnapshot,
        dashboardItems: [StatsMacDashboardItem]
    ) -> some View {
        let items = summaryCardItems(snapshot: snapshot, orderedBy: dashboardItems)
        if !items.isEmpty {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: summaryCardMinimumWidth,
                            maximum: summaryCardMaximumWidth
                        ),
                        spacing: 14
                    )
                ],
                spacing: summaryCardSpacing
            ) {
                ForEach(items) { item in
                    editableDashboardSection(dashboardItem(for: item)) {
                        summaryCardView(for: item)
                    }
                }
            }
        }
    }

    private var summaryCardMinimumWidth: CGFloat {
        switch summaryDisplayMode {
        case .cards:
            return horizontalSizeClass == .compact ? 160 : 220
        case .compact:
            return horizontalSizeClass == .compact ? 240 : 220
        }
    }

    private var summaryCardMaximumWidth: CGFloat {
        switch summaryDisplayMode {
        case .cards:
            return 280
        case .compact:
            return 360
        }
    }

    private var summaryCardSpacing: CGFloat {
        summaryDisplayMode == .compact ? 10 : 14
    }

    @ViewBuilder
    private func summaryCardView(for item: StatsSummaryCardItem) -> some View {
        switch summaryDisplayMode {
        case .cards:
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
                summaryCardAccessory(for: item)
            }
        case .compact:
            StatsCompactSummaryCard(
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
                summaryCardAccessory(for: item)
            }
        }
    }

    @ViewBuilder
    private func summaryCardAccessory(for item: StatsSummaryCardItem) -> some View {
        if item.showsAccessory {
            activeItemsInfoButton
        }
    }

    private func summaryCardItems(
        snapshot: DashboardSnapshot,
        orderedBy dashboardItems: [StatsMacDashboardItem]
    ) -> [StatsSummaryCardItem] {
        let items = StatsSummaryCardItemBuilder.items(
            metrics: snapshot.metrics,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            taskTypeFilter: snapshot.selectedTaskTypeFilter,
            filteredTaskCount: snapshot.filteredTaskCount,
            showsActiveAccessory: true
        )
        let itemsByDashboardItem = Dictionary(
            uniqueKeysWithValues: items.map { (dashboardItem(for: $0), $0) }
        )

        return dashboardItems.compactMap { itemsByDashboardItem[$0] }
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

    private var summaryDisplayModeMenu: some View {
        Menu {
            Picker("Summary view", selection: summaryDisplayModeBinding) {
                ForEach(StatsSummaryDisplayMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Summary view", systemImage: summaryDisplayMode.systemImage)
        }
        .help("Change summary card density")
        .accessibilityLabel("Summary card view")
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
            .disabled(hiddenDashboardItemIDs.isEmpty && dashboardItemOrderIDsRaw.isEmpty)
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
            outcomePoints: metrics.outcomeMixChartPoints,
            highlightedPoint: metrics.highlightedBusiestDay,
            averagePerDay: metrics.averagePerDay,
            chartUpperBound: metrics.chartUpperBound,
            xAxisDates: snapshot.chartPresentation.dailyBarXAxisDates(from: metrics.chartPoints),
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

    private func hourlyActivitySection(snapshot: DashboardSnapshot) -> some View {
        StatsHourlyActivitySection(
            points: snapshot.metrics.hourlyActivityChartPoints,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
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
            focusWeekdayAveragePoints: metrics.focusWeekdayAveragePoints,
            highlightedFocusDay: metrics.highlightedFocusDay,
            highlightedFocusWeekdayAverage: metrics.highlightedFocusWeekdayAverage,
            averageFocusSecondsPerDay: metrics.averageFocusSecondsPerDay,
            focusChartUpperBound: metrics.focusChartUpperBound,
            focusWeekdayAverageUpperBound: metrics.focusWeekdayAverageUpperBound,
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

    private func focus2048Section(snapshot: DashboardSnapshot) -> some View {
        StatsFocus2048Section(
            totalFocusSeconds: snapshot.metrics.totalFocusSeconds,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func achievementsSection() -> some View {
        StatsAchievementsSection(
            achievements: StatsAchievementStats.achievements(
                focusSessions: store.focusSessions,
                sleepSessions: statsSleepSessions,
                awaySessions: statsAwaySessions,
                logs: store.logs,
                emotionLogs: store.emotionLogs,
                notes: store.notes,
                noteAttachmentNoteIDs: store.noteAttachmentNoteIDs,
                goals: store.goals,
                places: statsPlaces,
                placeCheckInSessions: statsPlaceCheckInSessions,
                calendar: calendar
            ),
            earnedAchievementIDsByPeriod: StatsAchievementStats.achievementIDsEarnedByPeriod(
                focusSessions: store.focusSessions,
                sleepSessions: statsSleepSessions,
                awaySessions: statsAwaySessions,
                logs: store.logs,
                emotionLogs: store.emotionLogs,
                notes: store.notes,
                noteAttachmentNoteIDs: store.noteAttachmentNoteIDs,
                goals: store.goals,
                places: statsPlaces,
                placeCheckInSessions: statsPlaceCheckInSessions,
                referenceDate: Date(),
                calendar: calendar
            ),
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func recentWinsSection() -> some View {
        StatsRecentWinsSection(
            celebrations: StatsAchievementStats.celebrationPeriods(
                focusSessions: store.focusSessions,
                sleepSessions: statsSleepSessions,
                awaySessions: statsAwaySessions,
                logs: store.logs,
                emotionLogs: store.emotionLogs,
                notes: store.notes,
                goals: store.goals,
                places: statsPlaces,
                placeCheckInSessions: statsPlaceCheckInSessions,
                referenceDate: Date(),
                calendar: calendar
            ),
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
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

    private func focusWorkChartSection(snapshot: DashboardSnapshot) -> some View {
        StatsFocusWorkChartSection(
            points: snapshot.metrics.focusWorkChartPoints,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func estimateActualChartSection(snapshot: DashboardSnapshot) -> some View {
        StatsEstimateActualChartSection(
            points: snapshot.metrics.estimateActualChartPoints,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func goalProgressSection(snapshot: DashboardSnapshot) -> some View {
        StatsGoalProgressSection(
            points: snapshot.metrics.goalProgressChartPoints,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func emotionTrendSection(snapshot: DashboardSnapshot) -> some View {
        StatsEmotionTrendSection(
            points: snapshot.metrics.emotionTrendChartPoints,
            selectedRange: snapshot.selectedRange,
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

    private var contentBottomPadding: CGFloat {
        36
    }

    private func isDashboardItemVisible(_ item: StatsMacDashboardItem) -> Bool {
        !hiddenDashboardItemIDs.contains(item.rawValue)
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
        setDashboardItemOrderIDs([])
    }

    private func setHiddenDashboardItemIDs(_ itemIDs: Set<String>) {
        let rawValue = itemIDs.sorted().joined(separator: ",")
        CloudSettingsKeyValueSync.setString(
            rawValue,
            for: .appSettingMacStatsDashboardHiddenItemIDs
        )
    }

    private func moveDashboardItem(_ draggedItemID: String, before targetItemID: String) {
        let defaultItemIDs = StatsMacDashboardItem.allCases.map(\.rawValue)
        let orderedItemIDs = StatsDashboardOrderSupport.normalizedItemIDs(
            defaultItemIDs: defaultItemIDs,
            storedRawValue: dashboardItemOrderIDsRaw
        )
        let movedItemIDs = StatsDashboardOrderSupport.movedItemIDs(
            draggedItemID: draggedItemID,
            before: targetItemID,
            in: orderedItemIDs
        )
        setDashboardItemOrderIDs(movedItemIDs)
    }

    private func setDashboardItemOrderIDs(_ itemIDs: [String]) {
        let defaultItemIDs = StatsMacDashboardItem.allCases.map(\.rawValue)
        let rawValue = StatsDashboardOrderSupport.storedRawValue(
            for: itemIDs,
            defaultItemIDs: defaultItemIDs
        )
        CloudSettingsKeyValueSync.setString(
            rawValue,
            for: .appSettingMacStatsDashboardItemOrderIDs
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
                        .routinaGlassPill(interactive: true)
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

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .routinaGlassPill(interactive: true)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 7, y: -10)
                        .help("Move \(item.title)")
                        .accessibilityLabel("Move \(item.title)")
                }
                .contentShape(Rectangle())
                .onDrag {
                    draggedDashboardItemID = item.rawValue
                    return NSItemProvider(object: item.rawValue as NSString)
                }
                .onDrop(
                    of: StatsDashboardReorderDropDelegate.supportedContentTypes,
                    delegate: StatsDashboardReorderDropDelegate(
                        itemID: item.rawValue,
                        draggedItemID: $draggedDashboardItemID,
                        orderedItemIDs: scopedVisibleOrderedDashboardItems.map(\.rawValue),
                        onMove: moveDashboardItem
                    )
                )
                .zIndex(draggedDashboardItemID == item.rawValue ? 1 : 0)
            } else {
                content()
            }
        }
    }
}
