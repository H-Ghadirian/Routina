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
    let ownsCompactNavigationStack: Bool
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Query private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]
    @Query private var focusSessions: [FocusSession]
    @Query private var sprintFocusSessions: [SprintFocusSessionRecord]
    @Query private var boardSprints: [BoardSprintRecord]
    @Query private var sleepSessions: [SleepSession]
    @Query private var awaySessions: [AwaySession]
    @Query private var emotionLogs: [EmotionLog]
    @Query private var notes: [RoutineNote]
    @Query private var events: [RoutineEvent]
    @Query private var noteAttachments: [RoutineNoteAttachment]
    @Query private var goals: [RoutineGoal]
    @Query private var places: [RoutinePlace]
    @Query private var placeCheckInSessions: [PlaceCheckInSession]
    @State private var relatedFilterTagSuggestionAnchor: String?
    @State private var selectedDashboardScope = StatsDashboardScope.all
    @State private var isEditingDashboard = false
    @State private var isAddDashboardItemSheetPresented = false
    @State private var draggedDashboardItemID: String?
    @AppStorage(UserDefaultStringValueKey.appSettingIOSStatsDashboardHiddenItemIDs.rawValue, store: SharedDefaults.app)
    private var hiddenDashboardItemIDsRaw = ""
    @AppStorage(UserDefaultStringValueKey.appSettingIOSStatsDashboardItemOrderIDs.rawValue, store: SharedDefaults.app)
    private var dashboardItemOrderIDsRaw = ""
    @AppStorage(UserDefaultStringValueKey.appSettingIOSStatsSummaryDisplayMode.rawValue, store: SharedDefaults.app)
    private var summaryDisplayModeRaw = StatsSummaryDisplayMode.cards.rawValue

    private typealias Metrics = StatsFeature.Metrics

    init(
        store: StoreOf<StatsFeature>,
        ownsCompactNavigationStack: Bool = true
    ) {
        self.store = store
        self.ownsCompactNavigationStack = ownsCompactNavigationStack
    }

    private var chartPresentation: StatsChartPresentation {
        StatsChartPresentation(
            selectedRange: selectedRange,
            isCompact: horizontalSizeClass == .compact
        )
    }

    private var selectedRange: DoneChartRange {
        store.selectedRange
    }

    private var filterSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isFilterSheetPresented },
            set: { store.send(.setFilterSheet($0)) }
        )
    }

    private var taskTypeFilterBinding: Binding<StatsTaskTypeFilter> {
        Binding(
            get: { store.taskTypeFilter },
            set: { store.send(.taskTypeFilterChanged($0)) }
        )
    }

    private var advancedQueryBinding: Binding<String> {
        Binding(
            get: { store.advancedQuery },
            set: { store.send(.advancedQueryChanged($0)) }
        )
    }

    private var advancedQueryOptions: HomeAdvancedQueryOptions {
        HomeAdvancedQueryOptions(tags: availableTags, places: [])
    }

    private var metrics: Metrics {
        store.metrics
    }

    private var availableTags: [String] {
        store.availableTags
    }

    private var filterPresentation: StatsFilterPresentation {
        StatsFilterPresentation(
            taskTypeFilter: selectedTaskTypeFilter,
            advancedQuery: store.advancedQuery,
            selectedTags: store.effectiveSelectedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            excludedTags: store.excludedTags,
            excludeTagMatchMode: store.excludeTagMatchMode,
            selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
            availableTags: availableTags,
            relatedTagRules: store.relatedTagRules,
            tagColors: store.tagColors
        )
    }

    private var suggestedRelatedFilterTags: [String] {
        filterPresentation.suggestedRelatedTags(
            suggestionAnchor: relatedFilterTagSuggestionAnchor
        )
    }

    private var selectedTaskTypeFilter: StatsTaskTypeFilter {
        store.taskTypeFilter
    }

    private var availableExcludeTags: [String] {
        filterPresentation.availableExcludeTags(from: store.tasks)
    }

    private var tagRuleBindings: HomeTagRuleBindings {
        HomeTagRuleBindings(
            includeTagMatchMode: Binding(
                get: { store.includeTagMatchMode },
                set: { store.send(.includeTagMatchModeChanged($0)) }
            ),
            excludeTagMatchMode: Binding(
                get: { store.excludeTagMatchMode },
                set: { store.send(.excludeTagMatchModeChanged($0)) }
            )
        )
    }

    private var tagRuleData: HomeTagFilterData {
        filterPresentation.tagRuleData(
            suggestedRelatedTags: suggestedRelatedFilterTags,
            availableExcludeTags: availableExcludeTags
        )
    }

    private var tagRuleActions: HomeTagFilterActions {
        HomeTagFilterActions(
            onShowAllTags: {
                relatedFilterTagSuggestionAnchor = nil
                store.send(.selectedTagsChanged([]))
            },
            onToggleIncludedTag: toggleIncludedTag,
            onAddIncludedTag: addIncludedTag,
            onToggleExcludedTag: toggleExcludedTag
        )
    }

    private var hasActiveFilters: Bool {
        store.hasActiveFilters
    }

    private var hasActiveSheetFilters: Bool {
        filterPresentation.hasActiveSheetFilters
    }

    private var activeSheetFilterCount: Int {
        filterPresentation.activeSheetFilterCount
    }

    private func toggleIncludedTag(_ tag: String) {
        let mutation = filterPresentation.toggledIncludedTag(
            tag,
            currentSuggestionAnchor: relatedFilterTagSuggestionAnchor
        )
        relatedFilterTagSuggestionAnchor = mutation.suggestionAnchor
        store.send(.selectedTagsChanged(mutation.selectedTags))
    }

    private func addIncludedTag(_ tag: String) {
        guard let mutation = filterPresentation.addedIncludedTag(tag) else { return }
        store.send(.selectedTagsChanged(mutation.selectedTags))
    }

    private func toggleExcludedTag(_ tag: String) {
        let mutation = filterPresentation.toggledExcludedTag(tag)
        store.send(.selectedTagsChanged(mutation.selectedTags))
        store.send(.excludedTagsChanged(mutation.excludedTags))
    }

    private var filteredTaskCount: Int {
        store.filteredTaskCount
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

    private var baseBarFill: LinearGradient {
        StatsDashboardPalette.baseBarFill(colorScheme: colorScheme)
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

    private var availableDashboardItems: [StatsDashboardItem] {
        StatsDashboardItem.allCases.filter { item in
            item.isAvailable(
                selectedRange: selectedRange,
                isGitFeaturesEnabled: store.isGitFeaturesEnabled
            ) && (item != .unassignedFocus || hasUnassignedFocusSessions)
        }
    }

    private var orderedAvailableDashboardItems: [StatsDashboardItem] {
        StatsDashboardOrderSupport.orderedItems(
            availableDashboardItems,
            storedRawValue: dashboardItemOrderIDsRaw
        )
    }

    private var visibleOrderedDashboardItems: [StatsDashboardItem] {
        orderedAvailableDashboardItems.filter(isDashboardItemVisible)
    }

    private var scopedVisibleOrderedDashboardItems: [StatsDashboardItem] {
        visibleOrderedDashboardItems.filter { $0.isIncluded(in: selectedDashboardScope) }
    }

    private var hiddenAvailableDashboardItems: [StatsDashboardItem] {
        orderedAvailableDashboardItems.filter { hiddenDashboardItemIDs.contains($0.rawValue) }
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
                        for: .appSettingIOSStatsSummaryDisplayMode
                    )
                }
            }
        )
    }

    private var hasUnassignedFocusSessions: Bool {
        !FocusSessionSupport.unassignedCompletedSessions(from: focusSessions).isEmpty
    }

    private var shouldShowHealthAccessCard: Bool {
        store.healthAccessState != .ready
            || store.healthSummary == nil
            || store.healthStatsErrorMessage != nil
    }

    var body: some View {
        statsRoot
            .sheet(isPresented: filterSheetBinding) {
                statsFiltersSheet
            }
            .sheet(isPresented: $isAddDashboardItemSheetPresented) {
                addDashboardItemSheet
            }
            .statsDataRefresh(
                tasks: tasks,
                logs: logs,
                focusSessions: focusSessions,
                sprintFocusSessions: sprintFocusSessions,
                boardSprints: boardSprints,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                emotionLogs: emotionLogs,
                notes: notes,
                events: events,
                noteAttachmentNoteIDs: Set(noteAttachments.map(\.noteID)),
                goals: goals,
                places: places,
                placeCheckInSessions: placeCheckInSessions,
                onAppear: { store.send(.onAppear) },
                onDataChanged: { tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions in
                    store.send(
                        .setData(
                            tasks: tasks,
                            logs: logs,
                            focusSessions: focusSessions,
                            sprintFocusSessions: sprintFocusSessions,
                            boardSprints: boardSprints,
                            sleepSessions: sleepSessions,
                            awaySessions: awaySessions,
                            emotionLogs: emotionLogs,
                            notes: notes,
                            events: events,
                            noteAttachmentNoteIDs: noteAttachmentNoteIDs,
                            goals: goals,
                            places: places,
                            placeCheckInSessions: placeCheckInSessions
                        )
                    )
                }
            )
    }

    @ViewBuilder
    private var statsRoot: some View {
        if usesSidebarLayout {
            NavigationSplitView {
                statsSidebarContent
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
            } detail: {
                statsDashboardContent
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            if ownsCompactNavigationStack {
                NavigationStack {
                    statsDashboardContent
                }
            } else {
                statsDashboardContent
            }
        }
    }

    private var usesSidebarLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass != .compact
    }

    private var statsDashboardContent: some View {
        StatsDashboardScrollContainer(
            pageBackground: pageBackground,
            bottomPadding: contentBottomPadding,
            maxContentWidth: statsContentMaxWidth
        ) {
            let currentMetrics = metrics
            VStack(alignment: .leading, spacing: 24) {
                AnyView(rangeSection)
                AnyView(dashboardScopePicker)

                if hasActiveSheetFilters {
                    AnyView(activeFilterChipBar)
                }

                if isEditingDashboard {
                    AnyView(dashboardEditControls)
                }

                if shouldShowHealthAccessCard {
                    AnyView(healthAccessCard)
                }

                ForEach(dashboardBlocks(metrics: currentMetrics)) { block in
                    dashboardBlockView(block, metrics: currentMetrics)
                }
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                summaryDisplayModeMenu
                dashboardEditButton
                filterSheetButton
            }
        }
    }

    private var statsSidebarContent: some View {
        StatsSidebarContent(
            selectedRange: selectedRange,
            onSelectRange: { store.send(.selectedRangeChanged($0)) },
            showsTaskTypeFilter: tasks.contains(where: \.isOneOffTask),
            selectedTaskTypeFilter: selectedTaskTypeFilter,
            filteredTaskCount: filteredTaskCount,
            onSelectTaskTypeFilter: { store.send(.taskTypeFilterChanged($0)) },
            activeSheetFilterCount: activeSheetFilterCount,
            hasActiveSheetFilters: hasActiveSheetFilters,
            hasActiveFilters: hasActiveFilters,
            onShowFilters: { store.send(.setFilterSheet(true)) },
            onClearFilters: { store.send(.clearFilters) },
            isGitFeaturesEnabled: store.isGitFeaturesEnabled,
            gitHubConnection: gitHubConnection,
            isGitHubStatsLoading: isGitHubStatsLoading,
            onRefreshGitHubStats: { store.send(.gitHubStatsRefreshRequested) }
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                summaryDisplayModeMenu
                dashboardEditButton
                filterSheetButton
            }
        }
    }

    private func dashboardBlocks(metrics: Metrics) -> [StatsDashboardBlock] {
        var blocks: [StatsDashboardBlock] = []
        var pendingSummaryItems: [StatsDashboardItem] = []

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
                return !summaryCardItems(metrics: metrics, orderedBy: items).isEmpty
            }
        }
    }

    @ViewBuilder
    private func dashboardBlockView(_ block: StatsDashboardBlock, metrics: Metrics) -> some View {
        switch block {
        case let .section(item):
            dashboardSection(item, metrics: metrics)
        case let .summaryCards(items):
            summaryCards(metrics: metrics, dashboardItems: items)
        }
    }

    @ViewBuilder
    private var activeFilterChipBar: some View {
        StatsActiveFilterChipBar(
            selectedTaskTypeFilter: selectedTaskTypeFilter,
            advancedQuery: store.advancedQuery,
            selectedTags: store.effectiveSelectedTags,
            selectedImportanceUrgencyFilterLabel: selectedImportanceUrgencyFilterLabel,
            excludedTags: store.excludedTags,
            onClearAll: { store.send(.clearFilters) },
            onClearTaskType: { store.send(.taskTypeFilterChanged(.all)) },
            onClearAdvancedQuery: { store.send(.advancedQueryChanged("")) },
            onRemoveSelectedTag: { tag in
                var selected = store.effectiveSelectedTags
                selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
                store.send(.selectedTagsChanged(selected))
            },
            onClearImportanceUrgency: { store.send(.selectedImportanceUrgencyFilterChanged(nil)) },
            onRemoveExcludedTag: { tag in
                store.send(.excludedTagsChanged(store.excludedTags.filter { $0 != tag }))
            }
        )
    }

    private var filterSheetButton: some View {
        StatsFilterButton(
            hasActiveFilters: hasActiveFilters,
            onShowFilters: { store.send(.setFilterSheet(true)) }
        )
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
        .accessibilityLabel("Summary card view")
    }

    private var dashboardEditButton: some View {
        Button(isEditingDashboard ? "Done" : "Edit") {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isEditingDashboard.toggle()
            }
        }
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
                            .accessibilityLabel("Add \(item.title)")
                        }
                    }
                }
            }
            .navigationTitle("Add to Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isAddDashboardItemSheetPresented = false
                    }
                }
            }
        }
    }

    private var statsFiltersSheet: some View {
        StatsFiltersSheet(
            advancedQuery: advancedQueryBinding,
            advancedQueryOptions: advancedQueryOptions,
            showsTaskTypeFilter: tasks.contains(where: \.isOneOffTask),
            taskTypeFilter: taskTypeFilterBinding,
            selectedImportanceUrgencyFilter: Binding(
                get: { store.selectedImportanceUrgencyFilter },
                set: { store.send(.selectedImportanceUrgencyFilterChanged($0)) }
            ),
            importanceUrgencyFilterSummary: importanceUrgencyFilterSummary,
            tagRuleBindings: tagRuleBindings,
            tagRuleData: tagRuleData,
            tagRuleActions: tagRuleActions,
            hasActiveFilters: hasActiveFilters,
            selectedTags: store.effectiveSelectedTags,
            availableTags: availableTags,
            onClearFilters: { store.send(.clearFilters) },
            onClose: { store.send(.setFilterSheet(false)) },
            onSelectedTagsPruned: { store.send(.selectedTagsChanged($0)) }
        )
    }

    private var selectedImportanceUrgencyFilterLabel: String? {
        guard let filter = ImportanceUrgencyFilterCell.normalized(store.selectedImportanceUrgencyFilter) else {
            return nil
        }
        return "\(filter.importance.shortTitle)/\(filter.urgency.shortTitle)+"
    }

    private var importanceUrgencyFilterSummary: String {
        guard let filter = ImportanceUrgencyFilterCell.normalized(store.selectedImportanceUrgencyFilter) else {
            return "Showing stats across all importance and urgency levels."
        }
        return "Showing stats for tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    private var rangeSection: some View {
        StatsRangeSelectorView(selectedRange: selectedRange) { range in
            _ = store.send(.selectedRangeChanged(range))
        }
    }

    private var dashboardScopePicker: some View {
        Picker("Stats category", selection: $selectedDashboardScope) {
            ForEach(StatsDashboardScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 440)
        .accessibilityIdentifier("stats.dashboard.scopePicker")
    }

    @ViewBuilder
    private func dashboardSection(_ item: StatsDashboardItem, metrics: Metrics) -> some View {
        switch item {
        case .hero:
            editableDashboardSection(.hero) {
                heroSection(metrics: metrics)
            }
        case .unassignedFocus:
            editableDashboardSection(.unassignedFocus) {
                UnassignedFocusSessionsCard(focusSessions: focusSessions)
            }
        case .completionChart:
            editableDashboardSection(.completionChart) {
                chartSection(metrics: metrics)
            }
        case .hourlyActivity:
            editableDashboardSection(.hourlyActivity) {
                hourlyActivitySection(metrics: metrics)
            }
        case .tagUsage:
            editableDashboardSection(.tagUsage) {
                tagUsageSection(metrics: metrics)
            }
        case .focusChart:
            editableDashboardSection(.focusChart) {
                focusChartSection(metrics: metrics)
            }
        case .focus2048:
            editableDashboardSection(.focus2048) {
                focus2048Section(metrics: metrics)
            }
        case .focusAchievements:
            editableDashboardSection(.focusAchievements) {
                achievementsSection()
            }
        case .focusWorkChart:
            editableDashboardSection(.focusWorkChart) {
                focusWorkChartSection(metrics: metrics)
            }
        case .estimateActual:
            editableDashboardSection(.estimateActual) {
                estimateActualChartSection(metrics: metrics)
            }
        case .goalProgress:
            editableDashboardSection(.goalProgress) {
                goalProgressSection(metrics: metrics)
            }
        case .emotionTrend:
            editableDashboardSection(.emotionTrend) {
                emotionTrendSection(metrics: metrics)
            }
        case .gitHub:
            editableDashboardSection(.gitHub) {
                gitHubSection
            }
        default:
            EmptyView()
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

    @ViewBuilder
    private func summaryCards(metrics: Metrics, dashboardItems: [StatsDashboardItem]) -> some View {
        let items = summaryCardItems(metrics: metrics, orderedBy: dashboardItems)
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
                EmptyView()
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
                EmptyView()
            }
        }
    }

    private func summaryCardItems(
        metrics: Metrics,
        orderedBy dashboardItems: [StatsDashboardItem]
    ) -> [StatsSummaryCardItem] {
        let items = StatsSummaryCardItemBuilder.items(
            metrics: metrics,
            selectedRange: selectedRange,
            chartPresentation: chartPresentation,
            taskTypeFilter: .routines,
            filteredTaskCount: filteredTaskCount,
            healthSummary: store.healthSummary
        )
        let itemsByDashboardItem = Dictionary(
            uniqueKeysWithValues: items.map { (dashboardItem(for: $0), $0) }
        )

        return dashboardItems.compactMap { itemsByDashboardItem[$0] }
    }

    private var gitHubSection: some View {
        StatsGitHubSection(
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

    private var healthAccessCard: some View {
        StatsHealthAccessCard(
            accessState: store.healthAccessState,
            isLoading: store.isHealthStatsLoading,
            errorMessage: store.healthStatsErrorMessage,
            colorScheme: colorScheme,
            onRequestAccess: { store.send(.healthStatsAuthorizationRequested) },
            onRefresh: { store.send(.healthStatsRefreshRequested) }
        )
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
            outcomePoints: metrics.outcomeMixChartPoints,
            highlightedPoint: metrics.highlightedBusiestDay,
            averagePerDay: metrics.averagePerDay,
            chartUpperBound: metrics.chartUpperBound,
            xAxisDates: chartPresentation.dailyBarXAxisDates(from: metrics.chartPoints),
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

    private func hourlyActivitySection(metrics: Metrics) -> some View {
        StatsHourlyActivitySection(
            points: metrics.hourlyActivityChartPoints,
            selectedRange: selectedRange,
            chartPresentation: chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
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
            focusWeekdayAveragePoints: metrics.focusWeekdayAveragePoints,
            highlightedFocusDay: metrics.highlightedFocusDay,
            highlightedFocusWeekdayAverage: metrics.highlightedFocusWeekdayAverage,
            averageFocusSecondsPerDay: metrics.averageFocusSecondsPerDay,
            focusChartUpperBound: metrics.focusChartUpperBound,
            focusWeekdayAverageUpperBound: metrics.focusWeekdayAverageUpperBound,
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

    private func focus2048Section(metrics: Metrics) -> some View {
        StatsFocus2048Section(
            totalFocusSeconds: metrics.totalFocusSeconds,
            selectedRange: selectedRange,
            chartPresentation: chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func achievementsSection() -> some View {
        StatsAchievementsSection(
            achievements: StatsAchievementStats.achievements(
                focusSessions: focusSessions,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                logs: logs,
                emotionLogs: emotionLogs,
                notes: notes,
                noteAttachmentNoteIDs: Set(noteAttachments.map(\.noteID)),
                goals: goals,
                places: places,
                placeCheckInSessions: placeCheckInSessions,
                calendar: calendar
            ),
            celebrations: StatsAchievementStats.celebrationPeriods(
                focusSessions: focusSessions,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                logs: logs,
                emotionLogs: emotionLogs,
                notes: notes,
                goals: goals,
                places: places,
                placeCheckInSessions: placeCheckInSessions,
                referenceDate: Date(),
                calendar: calendar
            ),
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
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

    private func focusWorkChartSection(metrics: Metrics) -> some View {
        StatsFocusWorkChartSection(
            points: metrics.focusWorkChartPoints,
            selectedRange: selectedRange,
            chartPresentation: chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func estimateActualChartSection(metrics: Metrics) -> some View {
        StatsEstimateActualChartSection(
            points: metrics.estimateActualChartPoints,
            selectedRange: selectedRange,
            chartPresentation: chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func goalProgressSection(metrics: Metrics) -> some View {
        StatsGoalProgressSection(
            points: metrics.goalProgressChartPoints,
            selectedRange: selectedRange,
            chartPresentation: chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func emotionTrendSection(metrics: Metrics) -> some View {
        StatsEmotionTrendSection(
            points: metrics.emotionTrendChartPoints,
            selectedRange: selectedRange,
            chartPresentation: chartPresentation,
            surfaceGradient: surfaceGradient,
            colorScheme: colorScheme
        )
    }

    private func smallHighlightBadge(title: String, value: String) -> some View {
        StatsSmallHighlightBadge(
            title: title,
            value: value,
            colorScheme: colorScheme,
            surfaceGradient: surfaceGradient
        )
    }

    private var statsContentMaxWidth: CGFloat? {
        horizontalSizeClass == .regular ? 980 : nil
    }

    private var contentBottomPadding: CGFloat {
        horizontalSizeClass == .compact ? 120 : 52
    }

    private func isDashboardItemVisible(_ item: StatsDashboardItem) -> Bool {
        !hiddenDashboardItemIDs.contains(item.rawValue)
    }

    private func dashboardItem(for item: StatsSummaryCardItem) -> StatsDashboardItem {
        StatsDashboardItem(summaryAccessibilityIdentifier: item.accessibilityIdentifier)
    }

    private func removeDashboardItem(_ item: StatsDashboardItem) {
        var hiddenIDs = hiddenDashboardItemIDs
        hiddenIDs.insert(item.rawValue)
        setHiddenDashboardItemIDs(hiddenIDs)
    }

    private func addDashboardItem(_ item: StatsDashboardItem) {
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
            rawValue.isEmpty ? nil : rawValue,
            for: .appSettingIOSStatsDashboardHiddenItemIDs
        )
    }

    private func moveDashboardItem(_ draggedItemID: String, before targetItemID: String) {
        let defaultItemIDs = StatsDashboardItem.allCases.map(\.rawValue)
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
        let defaultItemIDs = StatsDashboardItem.allCases.map(\.rawValue)
        let rawValue = StatsDashboardOrderSupport.storedRawValue(
            for: itemIDs,
            defaultItemIDs: defaultItemIDs
        )
        CloudSettingsKeyValueSync.setString(
            rawValue,
            for: .appSettingIOSStatsDashboardItemOrderIDs
        )
    }

    private func editableDashboardSection<Content: View>(
        _ item: StatsDashboardItem,
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
