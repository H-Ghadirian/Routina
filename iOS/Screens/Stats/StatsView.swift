import Charts
import ComposableArchitecture
import SwiftData
import SwiftUI
import UIKit

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
    @State private var relatedFilterTagSuggestionAnchor: String?
    @State private var isEditingDashboard = false
    @State private var isAddDashboardItemSheetPresented = false
    @AppStorage(UserDefaultStringValueKey.appSettingIOSStatsDashboardHiddenItemIDs.rawValue, store: SharedDefaults.app)
    private var hiddenDashboardItemIDsRaw = ""

    private typealias Metrics = StatsFeature.Metrics

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
            )
        }
    }

    private var hiddenAvailableDashboardItems: [StatsDashboardItem] {
        availableDashboardItems.filter { hiddenDashboardItemIDs.contains($0.rawValue) }
    }

    var body: some View {
        WithPerceptionTracking {
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
                    onAppear: { store.send(.onAppear) },
                    onDataChanged: { tasks, logs, focusSessions in
                        store.send(.setData(tasks: tasks, logs: logs, focusSessions: focusSessions))
                    }
                )
        }
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
            NavigationStack {
                statsDashboardContent
            }
        }
    }

    private var usesSidebarLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
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
                if hasActiveSheetFilters {
                    AnyView(activeFilterChipBar)
                }

                if isEditingDashboard {
                    AnyView(dashboardEditControls)
                }

                if isDashboardItemVisible(.hero) {
                    AnyView(
                        editableDashboardSection(.hero) {
                            heroSection(metrics: currentMetrics)
                        }
                    )
                }

                AnyView(summaryCards(metrics: currentMetrics))

                if selectedRange != .today, isDashboardItemVisible(.completionChart) {
                    AnyView(
                        editableDashboardSection(.completionChart) {
                            chartSection(metrics: currentMetrics)
                        }
                    )
                }

                if isDashboardItemVisible(.tagUsage) {
                    AnyView(
                        editableDashboardSection(.tagUsage) {
                            tagUsageSection(metrics: currentMetrics)
                        }
                    )
                }

                if selectedRange != .today, isDashboardItemVisible(.focusChart) {
                    AnyView(
                        editableDashboardSection(.focusChart) {
                            focusChartSection(metrics: currentMetrics)
                        }
                    )
                }

                if store.isGitFeaturesEnabled, isDashboardItemVisible(.gitHub) {
                    AnyView(
                        editableDashboardSection(.gitHub) {
                            gitHubSection
                        }
                    )
                }
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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
                dashboardEditButton
                filterSheetButton
            }
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
        guard let filter = store.selectedImportanceUrgencyFilter else { return nil }
        return "\(filter.importance.shortTitle)/\(filter.urgency.shortTitle)+"
    }

    private var importanceUrgencyFilterSummary: String {
        guard let filter = store.selectedImportanceUrgencyFilter else {
            return "Choose a cell to show stats only for tasks that meet or exceed that importance and urgency."
        }
        return "Showing stats for tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    private var rangeSection: some View {
        StatsRangeSelectorView(selectedRange: selectedRange) { range in
            _ = store.send(.selectedRangeChanged(range))
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
        let items = visibleSummaryCardItems(
            StatsSummaryCardItemBuilder.items(
                metrics: metrics,
                selectedRange: selectedRange,
                chartPresentation: chartPresentation,
                taskTypeFilter: .routines,
                filteredTaskCount: filteredTaskCount
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
                        EmptyView()
                    }
                }
            }
        }
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

    private func visibleSummaryCardItems(_ items: [StatsSummaryCardItem]) -> [StatsSummaryCardItem] {
        items.filter { item in
            isDashboardItemVisible(dashboardItem(for: item))
        }
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
    }

    private func setHiddenDashboardItemIDs(_ itemIDs: Set<String>) {
        let rawValue = itemIDs.sorted().joined(separator: ",")
        CloudSettingsKeyValueSync.setString(
            rawValue.isEmpty ? nil : rawValue,
            for: .appSettingIOSStatsDashboardHiddenItemIDs
        )
    }

    private func editableDashboardSection<Content: View>(
        _ item: StatsDashboardItem,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topLeading) {
            content()
                .opacity(isEditingDashboard ? 0.96 : 1)

            if isEditingDashboard {
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
        }
    }
}

private enum StatsDashboardItem: String, CaseIterable, Identifiable {
    case hero
    case dailyAverage
    case focusTime
    case focusAverage
    case bestDay
    case totalDones
    case totalCancels
    case activeItems
    case archivedItems
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
