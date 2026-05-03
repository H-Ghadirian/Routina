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

    private var selectedRangeBinding: Binding<DoneChartRange> {
        Binding(
            get: { store.selectedRange },
            set: { store.send(.selectedRangeChanged($0)) }
        )
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

    private var selectorOutlineOpacity: Double {
        colorScheme == .dark ? 0.08 : 0.45
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
            statsRoot
                .sheet(isPresented: filterSheetBinding) {
                    statsFiltersSheet
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
        ScrollView(.vertical, showsIndicators: false) {
            let currentMetrics = metrics
            VStack(alignment: .leading, spacing: 24) {
                AnyView(rangeSection)
                if hasActiveSheetFilters {
                    AnyView(activeFilterChipBar)
                }
                AnyView(heroSection(metrics: currentMetrics))
                AnyView(summaryCards(metrics: currentMetrics))
                if selectedRange != .today {
                    AnyView(chartSection(metrics: currentMetrics))
                }
                AnyView(tagUsageSection(metrics: currentMetrics))
                if selectedRange != .today {
                    AnyView(focusChartSection(metrics: currentMetrics))
                }
                if store.isGitFeaturesEnabled {
                    AnyView(gitHubSection)
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
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
            ToolbarItem(placement: .primaryAction) {
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
        HStack(spacing: 10) {
            ForEach(DoneChartRange.allCases) { range in
                rangeButton(for: range)
            }
        }
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(selectorBackground)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white, lineWidth: 1)
                .opacity(selectorOutlineOpacity)
        )
    }

    private func rangeButton(for range: DoneChartRange) -> some View {
        let isSelected = selectedRange == range

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                _ = store.send(.selectedRangeChanged(range))
            }
        } label: {
            VStack(spacing: 4) {
                Text(range.rawValue)
                    .font(.subheadline.weight(.semibold))

                Text(rangeButtonSubtitle(for: range))
                    .font(.caption2.weight(.medium))
                    .opacity(isSelected ? 0.9 : 0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                rangeButtonBackground(isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
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
                title: "Active routines",
                value: metrics.activeRoutineCount.formatted(),
                caption: activeRoutineCardCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.activeRoutines"
            )

            summaryCard(
                icon: "archivebox.fill",
                accent: .teal,
                title: "Archived routines",
                value: metrics.archivedRoutineCount.formatted(),
                caption: archivedRoutineCardCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.archivedRoutines"
            )
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

    private func activeRoutineCardCaption(metrics: Metrics) -> String {
        if filteredTaskCount == 0 {
            return "No routines created yet"
        }

        if metrics.activeRoutineCount == 0 {
            return metrics.archivedRoutineCount == 1
                ? "Your only routine is paused"
                : "All routines are currently paused"
        }

        if metrics.archivedRoutineCount == 0 {
            return "Everything is currently in rotation"
        }

        return metrics.archivedRoutineCount == 1
            ? "1 paused routine excluded"
            : "\(metrics.archivedRoutineCount) paused routines excluded"
    }

    private func archivedRoutineCardCaption(metrics: Metrics) -> String {
        if filteredTaskCount == 0 {
            return "No routines created yet"
        }

        if metrics.archivedRoutineCount == 0 {
            return "No archived routines right now"
        }

        return metrics.archivedRoutineCount == 1
            ? "1 routine is paused and hidden from Home"
            : "\(metrics.archivedRoutineCount) routines are paused and hidden from Home"
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
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryCard(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        caption: String,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(colorScheme == .dark ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(surfaceGradient)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(accent.opacity(colorScheme == .dark ? 0.16 : 0.12))
                        .frame(width: 110, height: 110)
                        .blur(radius: 16)
                        .offset(x: 28, y: -32)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(value). \(caption)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func smallHighlightBadge(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35), lineWidth: 1)
        )
    }

    private func bottomInsightPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(colorScheme == .dark ? 0.14 : 0.04), in: Capsule(style: .continuous))
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
        horizontalSizeClass == .compact ? 120 : 52
    }

    private func tagUsageBubbleColor(for point: TagUsageChartPoint) -> Color {
        Color(routineTagHex: point.colorHex)
            ?? Color.accentColor.opacity(colorScheme == .dark ? 0.78 : 0.68)
    }

    @ViewBuilder
    private func rangeButtonBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selectorActiveFill)
                .shadow(color: Color.accentColor.opacity(0.28), radius: 16, y: 8)
        }
    }
}
