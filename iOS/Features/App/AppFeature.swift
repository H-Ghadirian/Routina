import ComposableArchitecture
import Foundation

enum StatsTaskTypeFilter: String, CaseIterable, Identifiable, Sendable, Equatable, Codable {
    case all = "All"
    case routines = "Routines"
    case todos = "Todos"

    var id: Self { self }
}

@Reducer
struct AppFeature {

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var hasRestoredTemporaryViewState = false
        var home = HomeFeature.State()
        var timeline = TimelineFeature.State()
        var stats = StatsFeature.State()
        var settings = SettingsFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case homeFastFilterSelected(String)
        case home(HomeFeature.Action)
        case timeline(TimelineFeature.Action)
        case stats(StatsFeature.Action)
        case settings(SettingsFeature.Action)
        case onAppear
        case cloudSettingsChanged
    }

    @Dependency(\.appSettingsClient) var appSettingsClient

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.timeline, action: \.timeline) {
            TimelineFeature()
        }
        Scope(state: \.stats, action: \.stats) {
            StatsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                persistTemporaryViewState(state)
                return .none
            case let .homeFastFilterSelected(tag):
                state.selectedTab = .home
                persistTemporaryViewState(state)
                return .send(.home(.applyFastTagFilter(tag)))
            case .onAppear:
                guard !state.hasRestoredTemporaryViewState else { return .none }
                state.hasRestoredTemporaryViewState = true
                applyTemporaryViewState(appSettingsClient.temporaryViewState(), to: &state)
                return .none
            case .cloudSettingsChanged:
                let tagColors = appSettingsClient.tagColors()
                let relatedTagRules = appSettingsClient.relatedTagRules()
                state.home.tagColors = tagColors
                state.home.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.home.routineTasks.map(\.tags))
                )
                state.timeline.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.timeline.tasks.map(\.tags))
                )
                state.stats.tagColors = tagColors
                state.stats.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.stats.tasks.map(\.tags))
                )
                SettingsTagEditor.loadedTagColors(tagColors, state: &state.settings.tags)
                SettingsTagEditor.loadedRelatedTagRules(relatedTagRules, state: &state.settings.tags)
                return .none
            case .settings(.resetTemporaryViewStateTapped):
                let timelineTasks = state.timeline.tasks
                let timelineLogs = state.timeline.logs
                let statsTasks = state.stats.tasks
                let statsLogs = state.stats.logs
                let statsFocusSessions = state.stats.focusSessions
                resetTemporaryViewState(&state)
                persistTemporaryViewState(state)
                return .merge(
                    .send(.timeline(.setData(tasks: timelineTasks, logs: timelineLogs))),
                    .send(.stats(.setData(tasks: statsTasks, logs: statsLogs, focusSessions: statsFocusSessions)))
                )
            case .timeline(.selectedRangeChanged),
                 .timeline(.filterTypeChanged),
                 .timeline(.selectedTagChanged),
                 .timeline(.selectedTagsChanged),
                 .timeline(.includeTagMatchModeChanged),
                 .timeline(.selectedImportanceUrgencyFilterChanged),
                 .timeline(.excludedTagsChanged),
                 .timeline(.excludeTagMatchModeChanged),
                 .timeline(.clearFilters),
                 .stats(.selectedRangeChanged),
                 .stats(.taskTypeFilterChanged),
                 .stats(.selectedTagChanged),
                 .stats(.selectedTagsChanged),
                 .stats(.includeTagMatchModeChanged),
                 .stats(.advancedQueryChanged),
                 .stats(.selectedImportanceUrgencyFilterChanged),
                 .stats(.excludedTagsChanged),
                 .stats(.excludeTagMatchModeChanged),
                 .stats(.clearFilters):
                persistTemporaryViewState(state)
                return .none
            case .settings(.tagColorChanged):
                let tagColors = appSettingsClient.tagColors()
                state.home.tagColors = tagColors
                state.stats.tagColors = tagColors
                return .none
            default:
                return .none
            }
        }
    }

    private func applyTemporaryViewState(_ persistedState: TemporaryViewState?, to state: inout State) {
        let persistedState = persistedState ?? .default
        if let rawValue = persistedState.selectedAppTabRawValue,
           let tab = Tab(rawValue: rawValue) {
            state.selectedTab = tab
        }
        state.timeline.selectedRange = persistedState.timelineSelectedRange
        state.timeline.filterType = persistedState.timelineFilterType
        state.timeline.setSelectedTags(persistedState.timelineSelectedTags)
        if state.timeline.effectiveSelectedTags.isEmpty {
            state.timeline.setSelectedTag(persistedState.timelineSelectedTag)
        }
        state.timeline.includeTagMatchMode = persistedState.timelineIncludeTagMatchMode
        state.timeline.excludedTags = persistedState.timelineExcludedTags
        state.timeline.excludeTagMatchMode = persistedState.timelineExcludeTagMatchMode
        state.timeline.selectedImportanceUrgencyFilter = persistedState.timelineSelectedImportanceUrgencyFilter
        state.stats.selectedRange = persistedState.statsSelectedRange
        state.stats.setSelectedTags(persistedState.statsSelectedTags)
        if state.stats.effectiveSelectedTags.isEmpty {
            state.stats.setSelectedTag(persistedState.statsSelectedTag)
        }
        state.stats.includeTagMatchMode = persistedState.statsIncludeTagMatchMode
        state.stats.excludedTags = persistedState.statsExcludedTags
        state.stats.excludeTagMatchMode = persistedState.statsExcludeTagMatchMode
        state.stats.selectedImportanceUrgencyFilter = persistedState.statsSelectedImportanceUrgencyFilter
        state.stats.advancedQuery = persistedState.statsAdvancedQuery
        if let rawValue = persistedState.statsTaskTypeFilterRawValue,
           let filter = StatsTaskTypeFilter(rawValue: rawValue) {
            state.stats.taskTypeFilter = filter
        }
    }

    private func resetTemporaryViewState(_ state: inout State) {
        state.home.taskListMode = .all
        state.home.selectedFilter = .all
        state.home.advancedQuery = ""
        state.home.selectedTags = []
        state.home.includeTagMatchMode = .all
        state.home.excludedTags = []
        state.home.excludeTagMatchMode = .any
        state.home.selectedManualPlaceFilterID = nil
        state.home.selectedImportanceUrgencyFilter = nil
        state.home.selectedTodoStateFilter = nil
        state.home.selectedPressureFilter = nil
        state.home.tabFilterSnapshots = [:]
        state.home.hideUnavailableRoutines = false
        state.home.isFilterSheetPresented = false
        state.home.selectedTimelineRange = .all
        state.home.selectedTimelineFilterType = .all
        state.home.selectedTimelineTags = []
        state.home.selectedTimelineIncludeTagMatchMode = .all
        state.home.selectedTimelineExcludedTags = []
        state.home.selectedTimelineExcludeTagMatchMode = .any
        state.home.selectedTimelineImportanceUrgencyFilter = nil
        state.home.statsSelectedRange = .week
        state.home.statsSelectedTags = []
        state.home.statsIncludeTagMatchMode = .all

        state.timeline.selectedRange = .all
        state.timeline.filterType = .all
        state.timeline.setSelectedTag(nil)
        state.timeline.includeTagMatchMode = .all
        state.timeline.selectedImportanceUrgencyFilter = nil
        state.timeline.excludedTags = []
        state.timeline.excludeTagMatchMode = .any
        state.timeline.isFilterSheetPresented = false
        state.timeline.availableTags = []
        state.timeline.groupedEntries = []

        state.stats.selectedRange = .week
        state.stats.isFilterSheetPresented = false
        state.stats.setSelectedTag(nil)
        state.stats.includeTagMatchMode = .all
        state.stats.excludedTags = []
        state.stats.excludeTagMatchMode = .any
        state.stats.selectedImportanceUrgencyFilter = nil
        state.stats.taskTypeFilter = .all
        state.stats.advancedQuery = ""
    }

    private func persistTemporaryViewState(_ state: State) {
        let existing = appSettingsClient.temporaryViewState() ?? .default
        appSettingsClient.setTemporaryViewState(
            TemporaryViewState(
                selectedAppTabRawValue: state.selectedTab.rawValue,
                homeTaskListModeRawValue: existing.homeTaskListModeRawValue,
                homeSelectedFilter: existing.homeSelectedFilter,
                homeAdvancedQuery: existing.homeAdvancedQuery,
                homeSelectedTag: existing.homeSelectedTag,
                homeSelectedTags: existing.homeSelectedTags,
                homeIncludeTagMatchMode: existing.homeIncludeTagMatchMode,
                homeExcludedTags: existing.homeExcludedTags,
                homeExcludeTagMatchMode: existing.homeExcludeTagMatchMode,
                homeSelectedManualPlaceFilterID: existing.homeSelectedManualPlaceFilterID,
                homeSelectedImportanceUrgencyFilter: existing.homeSelectedImportanceUrgencyFilter,
                homeSelectedTodoStateFilter: existing.homeSelectedTodoStateFilter,
                homeSelectedPressureFilter: existing.homeSelectedPressureFilter,
                homeTabFilterSnapshots: existing.homeTabFilterSnapshots,
                hideUnavailableRoutines: existing.hideUnavailableRoutines,
                homeSelectedTimelineRange: existing.homeSelectedTimelineRange,
                homeSelectedTimelineFilterType: existing.homeSelectedTimelineFilterType,
                homeSelectedTimelineTag: existing.homeSelectedTimelineTag,
                homeSelectedTimelineTags: existing.homeSelectedTimelineTags,
                homeTimelineIncludeTagMatchMode: existing.homeTimelineIncludeTagMatchMode,
                homeSelectedTimelineExcludedTags: existing.homeSelectedTimelineExcludedTags,
                homeTimelineExcludeTagMatchMode: existing.homeTimelineExcludeTagMatchMode,
                homeSelectedTimelineImportanceUrgencyFilter: existing.homeSelectedTimelineImportanceUrgencyFilter,
                macHomeSidebarModeRawValue: existing.macHomeSidebarModeRawValue,
                macSelectedSettingsSectionRawValue: existing.macSelectedSettingsSectionRawValue,
                timelineSelectedRange: state.timeline.selectedRange,
                timelineFilterType: state.timeline.filterType,
                timelineSelectedTag: state.timeline.selectedTag,
                timelineSelectedTags: state.timeline.effectiveSelectedTags,
                timelineIncludeTagMatchMode: state.timeline.includeTagMatchMode,
                timelineExcludedTags: state.timeline.excludedTags,
                timelineExcludeTagMatchMode: state.timeline.excludeTagMatchMode,
                timelineSelectedImportanceUrgencyFilter: state.timeline.selectedImportanceUrgencyFilter,
                statsSelectedRange: state.stats.selectedRange,
                statsSelectedTag: state.stats.selectedTag,
                statsSelectedTags: state.stats.effectiveSelectedTags,
                statsIncludeTagMatchMode: state.stats.includeTagMatchMode,
                statsExcludedTags: state.stats.excludedTags,
                statsExcludeTagMatchMode: state.stats.excludeTagMatchMode,
                statsSelectedImportanceUrgencyFilter: state.stats.selectedImportanceUrgencyFilter,
                statsTaskTypeFilterRawValue: state.stats.taskTypeFilter.rawValue,
                statsAdvancedQuery: state.stats.advancedQuery
            )
        )
    }
}

@Reducer
struct TimelineFeature {
    struct TimelineSection: Equatable, Identifiable {
        let date: Date
        var entries: [TimelineEntry]

        var id: Date { date }
    }

    @ObservableState
    struct State: Equatable {
        var tasks: [RoutineTask] = []
        var logs: [RoutineLog] = []
        var selectedRange: TimelineRange = .all
        var filterType: TimelineFilterType = .all
        var selectedTag: String?
        var selectedTags: Set<String> = []
        var includeTagMatchMode: RoutineTagMatchMode = .all
        var excludedTags: Set<String> = []
        var excludeTagMatchMode: RoutineTagMatchMode = .any
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var isFilterSheetPresented: Bool = false
        var availableTags: [String] = []
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var groupedEntries: [TimelineSection] = []

        var hasActiveFilters: Bool {
            selectedRange != .all || filterType != .all || !effectiveSelectedTags.isEmpty || !excludedTags.isEmpty || selectedImportanceUrgencyFilter != nil
        }

        var effectiveSelectedTags: Set<String> {
            if !selectedTags.isEmpty { return selectedTags }
            return selectedTag.map { [$0] } ?? []
        }

        mutating func setSelectedTag(_ tag: String?) {
            selectedTag = tag
            selectedTags = tag.map { [$0] } ?? []
        }

        mutating func setSelectedTags(_ tags: Set<String>) {
            selectedTags = tags
            selectedTag = tags.sorted().first
        }
    }

    enum Action: Equatable {
        case setData(tasks: [RoutineTask], logs: [RoutineLog])
        case selectedRangeChanged(TimelineRange)
        case filterTypeChanged(TimelineFilterType)
        case selectedTagChanged(String?)
        case selectedTagsChanged(Set<String>)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case setFilterSheet(Bool)
        case clearFilters
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.appSettingsClient) var appSettingsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setData(tasks, logs):
                state.tasks = tasks
                state.logs = logs
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
                )
                refreshDerivedState(&state)
                return .none

            case let .selectedRangeChanged(range):
                state.selectedRange = range
                refreshDerivedState(&state)
                return .none

            case let .filterTypeChanged(filterType):
                state.filterType = filterType
                refreshDerivedState(&state)
                return .none

            case let .selectedTagChanged(tag):
                state.setSelectedTag(tag)
                refreshDerivedState(&state)
                return .none

            case let .selectedTagsChanged(tags):
                state.setSelectedTags(tags)
                refreshDerivedState(&state)
                return .none

            case let .includeTagMatchModeChanged(mode):
                state.includeTagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .selectedImportanceUrgencyFilterChanged(filter):
                state.selectedImportanceUrgencyFilter = filter
                refreshDerivedState(&state)
                return .none

            case let .excludedTagsChanged(tags):
                state.excludedTags = tags
                refreshDerivedState(&state)
                return .none

            case let .excludeTagMatchModeChanged(mode):
                state.excludeTagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .setFilterSheet(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .clearFilters:
                state.selectedRange = .all
                state.filterType = .all
                state.setSelectedTag(nil)
                state.includeTagMatchMode = .all
                state.selectedImportanceUrgencyFilter = nil
                state.excludedTags = []
                state.excludeTagMatchMode = .any
                refreshDerivedState(&state)
                return .none
            }
        }
    }

    private func refreshDerivedState(_ state: inout State) {
        let baseEntries = TimelineLogic.filteredEntries(
            logs: state.logs,
            tasks: state.tasks,
            range: state.selectedRange,
            filterType: state.filterType,
            now: now,
            calendar: calendar
        )
        let importanceUrgencyFilteredEntries = baseEntries.filter { entry in
            HomeFeature.matchesImportanceUrgencyFilter(
                state.selectedImportanceUrgencyFilter,
                importance: entry.importance,
                urgency: entry.urgency
            )
        }
        state.availableTags = TimelineLogic.availableTags(from: importanceUrgencyFilteredEntries)
        state.setSelectedTags(state.effectiveSelectedTags.filter { RoutineTag.contains($0, in: state.availableTags) })
        let availableExcludeTags = state.availableTags.filter { tag in
            !state.effectiveSelectedTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
        state.excludedTags = state.excludedTags.filter { RoutineTag.contains($0, in: availableExcludeTags) }

        let entries = importanceUrgencyFilteredEntries.filter { entry in
            HomeFeature.matchesSelectedTags(
                state.effectiveSelectedTags,
                mode: state.includeTagMatchMode,
                in: entry.tags
            )
                && HomeFeature.matchesExcludedTags(
                    state.excludedTags,
                    mode: state.excludeTagMatchMode,
                    in: entry.tags
                )
        }
        state.groupedEntries = TimelineLogic.groupedByDay(entries: entries, calendar: calendar)
            .map { TimelineSection(date: $0.date, entries: $0.entries) }
    }
}

@Reducer
struct StatsFeature {
    struct Metrics: Equatable {
        var chartPoints: [DoneChartPoint] = []
        var focusChartPoints: [FocusDurationChartPoint] = []
        var totalDoneCount: Int = 0
        var totalCanceledCount: Int = 0
        var totalFocusSeconds: TimeInterval = 0
        var averageFocusSecondsPerDay: TimeInterval = 0
        var activeRoutineCount: Int = 0
        var archivedRoutineCount: Int = 0
        var totalCount: Int = 0
        var averagePerDay: Double = 0
        var highlightedBusiestDay: DoneChartPoint?
        var highlightedFocusDay: FocusDurationChartPoint?
        var activeDayCount: Int = 0
        var focusActiveDayCount: Int = 0
        var chartUpperBound: Double = 1
        var focusChartUpperBound: Double = 1
        var sparklinePoints: [DoneChartPoint] = []
        var sparklineMaxCount: Int = 1
        var xAxisDates: [Date] = []
    }

    @ObservableState
    struct State: Equatable {
        var tasks: [RoutineTask] = []
        var logs: [RoutineLog] = []
        var focusSessions: [FocusSession] = []
        var selectedRange: DoneChartRange = .week
        var taskTypeFilter: StatsTaskTypeFilter = .all
        var isFilterSheetPresented: Bool = false
        var selectedTag: String?
        var selectedTags: Set<String> = []
        var includeTagMatchMode: RoutineTagMatchMode = .all
        var excludedTags: Set<String> = []
        var excludeTagMatchMode: RoutineTagMatchMode = .any
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var advancedQuery: String = ""
        var availableTags: [String] = []
        var tagColors: [String: String] = [:]
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var filteredTaskCount: Int = 0
        var metrics = Metrics()
        var gitHubConnection = GitHubConnectionStatus.disconnected
        var gitHubStats: GitHubStatsSnapshot?
        var isGitHubStatsLoading: Bool = false
        var gitHubStatsErrorMessage: String?
        var isGitFeaturesEnabled: Bool = false

        var hasActiveFilters: Bool {
            selectedRange != .week
                || taskTypeFilter != .all
                || !advancedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !effectiveSelectedTags.isEmpty
                || !excludedTags.isEmpty
                || selectedImportanceUrgencyFilter != nil
        }

        var effectiveSelectedTags: Set<String> {
            if !selectedTags.isEmpty { return selectedTags }
            return selectedTag.map { [$0] } ?? []
        }

        mutating func setSelectedTag(_ tag: String?) {
            selectedTag = tag
            selectedTags = tag.map { [$0] } ?? []
        }

        mutating func setSelectedTags(_ tags: Set<String>) {
            selectedTags = tags
            selectedTag = tags.sorted().first
        }
    }

    enum Action: Equatable {
        case setData(tasks: [RoutineTask], logs: [RoutineLog], focusSessions: [FocusSession])
        case onAppear
        case selectedRangeChanged(DoneChartRange)
        case taskTypeFilterChanged(StatsTaskTypeFilter)
        case selectedTagChanged(String?)
        case selectedTagsChanged(Set<String>)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case advancedQueryChanged(String)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case setFilterSheet(Bool)
        case gitHubStatsRefreshRequested
        case gitHubStatsLoaded(GitHubStatsSnapshot)
        case gitHubStatsFailed(String)
        case clearFilters
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.gitHubStatsClient) var gitHubStatsClient
    @Dependency(\.gitLabStatsClient) var gitLabStatsClient
    @Dependency(\.appSettingsClient) var appSettingsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setData(tasks, logs, focusSessions):
                state.tasks = tasks
                state.logs = logs
                state.focusSessions = focusSessions
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
                )
                state.tagColors = appSettingsClient.tagColors()
                refreshDerivedState(&state)
                return .none

            case .onAppear:
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: state.tasks.map(\.tags))
                )
                state.tagColors = appSettingsClient.tagColors()
                state.isGitFeaturesEnabled = appSettingsClient.gitFeaturesEnabled()
                guard state.isGitFeaturesEnabled else {
                    state.gitHubConnection = .disconnected
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    return .none
                }
                state.gitHubConnection = gitHubStatsClient.loadConnectionStatus()
                if !state.gitHubConnection.isConnected {
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                }
                return refreshGitHubStatsEffect(state: &state)

            case let .selectedRangeChanged(range):
                state.selectedRange = range
                refreshDerivedState(&state)
                guard state.isGitFeaturesEnabled, state.gitHubConnection.isConnected else {
                    return .none
                }
                return refreshGitHubStatsEffect(state: &state, skipGitLab: true)

            case let .taskTypeFilterChanged(filter):
                state.taskTypeFilter = filter
                refreshDerivedState(&state)
                return .none

            case let .selectedTagChanged(tag):
                state.setSelectedTag(tag)
                refreshDerivedState(&state)
                return .none

            case let .selectedTagsChanged(tags):
                state.setSelectedTags(tags)
                refreshDerivedState(&state)
                return .none

            case let .includeTagMatchModeChanged(mode):
                state.includeTagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .advancedQueryChanged(query):
                state.advancedQuery = query
                refreshDerivedState(&state)
                return .none

            case let .selectedImportanceUrgencyFilterChanged(filter):
                state.selectedImportanceUrgencyFilter = filter
                refreshDerivedState(&state)
                return .none

            case let .excludedTagsChanged(tags):
                state.excludedTags = tags
                refreshDerivedState(&state)
                return .none

            case let .excludeTagMatchModeChanged(mode):
                state.excludeTagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .setFilterSheet(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .gitHubStatsRefreshRequested:
                state.isGitFeaturesEnabled = appSettingsClient.gitFeaturesEnabled()
                guard state.isGitFeaturesEnabled else {
                    state.gitHubConnection = .disconnected
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    state.isGitHubStatsLoading = false
                    return .none
                }
                state.gitHubConnection = gitHubStatsClient.loadConnectionStatus()
                if !state.gitHubConnection.isConnected {
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    state.isGitHubStatsLoading = false
                }
                return refreshGitHubStatsEffect(state: &state)

            case let .gitHubStatsLoaded(stats):
                state.isGitHubStatsLoading = false
                state.gitHubStats = stats
                state.gitHubStatsErrorMessage = nil
                return .none

            case let .gitHubStatsFailed(message):
                state.isGitHubStatsLoading = false
                state.gitHubStatsErrorMessage = message
                return .none

            case .clearFilters:
                state.selectedRange = .week
                state.taskTypeFilter = .all
                state.setSelectedTag(nil)
                state.includeTagMatchMode = .all
                state.excludedTags = []
                state.excludeTagMatchMode = .any
                state.selectedImportanceUrgencyFilter = nil
                state.advancedQuery = ""
                refreshDerivedState(&state)
                return .none
            }
        }
    }

    private func refreshGitHubStatsEffect(
        state: inout State,
        skipGitLab: Bool = false
    ) -> Effect<Action> {
        let isGitHubConnected = state.gitHubConnection.isConnected
        guard state.isGitFeaturesEnabled else {
            state.isGitHubStatsLoading = false
            state.gitHubStatsErrorMessage = nil
            return .none
        }
        if isGitHubConnected {
            state.isGitHubStatsLoading = true
            state.gitHubStatsErrorMessage = nil
        }
        let range = state.selectedRange
        let isProfile = state.gitHubConnection.scope == .profile

        return .run { send in
            if isGitHubConnected {
                do {
                    let stats = try await self.gitHubStatsClient.fetchStats(range)
                    await send(.gitHubStatsLoaded(stats))
                } catch {
                    await send(.gitHubStatsFailed(error.localizedDescription))
                }
            }
            if isGitHubConnected, isProfile {
                do {
                    let data = try await self.gitHubStatsClient.fetchContributionYear()
                    GitHubWidgetService.writeAndReload(data)
                } catch {
                    NSLog("GitHubWidgetService: fetchContributionYear failed — \(error.localizedDescription)")
                }
            } else if isGitHubConnected {
                NSLog("GitHubWidgetService: skipping widget fetch — scope is not profile")
            }

            if !skipGitLab, self.gitLabStatsClient.loadConnectionStatus().isConnected {
                do {
                    let data = try await self.gitLabStatsClient.fetchContributionYear()
                    GitLabWidgetService.writeAndReload(data)
                } catch {
                    NSLog("GitLabWidgetService: fetchContributionYear failed — \(error.localizedDescription)")
                }
            } else if !skipGitLab {
                NSLog("GitLabWidgetService: skipping widget fetch — not connected")
            }
        }
    }

    private func refreshDerivedState(_ state: inout State) {
        let tasksMatchingTypeFilter = state.tasks.filter { task in
            switch state.taskTypeFilter {
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
                state.selectedImportanceUrgencyFilter,
                importance: task.importance,
                urgency: task.urgency
            )
        }

        let query = HomeTaskAdvancedQuery<StatsTaskQueryDisplay>(state.advancedQuery)
        let queryDisplays = tasksMatchingMatrixFilter.map {
            StatsTaskQueryDisplay(task: $0, referenceDate: now, calendar: calendar)
        }
        let queryMetrics = HomeTaskListMetrics<StatsTaskQueryDisplay>(
            configuration: HomeTaskListFilteringConfiguration(
                selectedFilter: .all,
                advancedQuery: "",
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: nil,
                selectedPressureFilter: nil,
                taskListViewMode: .all,
                taskListSortOrder: .smart,
                createdDateFilter: .all,
                selectedTags: [],
                includeTagMatchMode: .all,
                excludedTags: [],
                excludeTagMatchMode: .any,
                searchText: "",
                routineListSectioningMode: .status,
                routineTasks: state.tasks,
                referenceDate: now,
                calendar: calendar
            )
        )
        let queryMatchedTaskIDs = Set(queryDisplays.filter { query.matches($0, metrics: queryMetrics) }.map(\.taskID))
        let tasksMatchingQuery = tasksMatchingMatrixFilter.filter { queryMatchedTaskIDs.contains($0.id) }

        state.availableTags = RoutineTag.allTags(from: tasksMatchingQuery.map { $0.tags })
        state.setSelectedTags(state.effectiveSelectedTags.filter { RoutineTag.contains($0, in: state.availableTags) })
        let availableExcludeTags = state.availableTags.filter { tag in
            !state.effectiveSelectedTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
        state.excludedTags = state.excludedTags.filter { RoutineTag.contains($0, in: availableExcludeTags) }

        let filteredTasks: [RoutineTask]
        let filteredLogs: [RoutineLog]
        let includeFilteredTasks = tasksMatchingQuery.filter { task in
            HomeFeature.matchesSelectedTags(
                state.effectiveSelectedTags,
                mode: state.includeTagMatchMode,
                in: task.tags
            )
        }
        filteredTasks = includeFilteredTasks.filter { task in
            HomeFeature.matchesExcludedTags(
                state.excludedTags,
                mode: state.excludeTagMatchMode,
                in: task.tags
            )
        }
        let filteredTaskIDs = Set(filteredTasks.map(\.id))
        filteredLogs = state.logs.filter { filteredTaskIDs.contains($0.taskID) }
        let filteredFocusSessions = state.focusSessions.filter { filteredTaskIDs.contains($0.taskID) }

        let completionDates = filteredLogs
            .filter { $0.kind == .completed }
            .compactMap(\.timestamp)
        let canceledDates = filteredLogs
            .filter { $0.kind == .canceled }
            .compactMap(\.timestamp)
        let earliestActivityDate = [
            filteredTasks.compactMap(\.createdAt).min(),
            filteredLogs.compactMap(\.timestamp).min(),
            filteredFocusSessions.compactMap(\.startedAt).min()
        ].compactMap { $0 }.min()
        let chartPoints = RoutineCompletionStats.points(
            for: state.selectedRange,
            timestamps: completionDates,
            earliestActivityDate: earliestActivityDate,
            referenceDate: now,
            calendar: calendar
        )
        let focusChartPoints = FocusDurationStats.points(
            for: state.selectedRange,
            sessions: filteredFocusSessions,
            earliestActivityDate: earliestActivityDate,
            referenceDate: now,
            calendar: calendar
        )
        let totalCount = RoutineCompletionStats.totalCount(in: chartPoints)
        let averagePerDay = RoutineCompletionStats.averageCount(in: chartPoints)
        let busiestDay = RoutineCompletionStats.busiestDay(in: chartPoints)
        let totalFocusSeconds = FocusDurationStats.totalSeconds(in: focusChartPoints)
        let averageFocusSecondsPerDay = FocusDurationStats.averageSeconds(in: focusChartPoints)
        let busiestFocusDay = FocusDurationStats.busiestDay(in: focusChartPoints)
        let sparklinePoints = sampledSparklinePoints(
            from: chartPoints,
            for: state.selectedRange
        )
        let maxCount = chartPoints.map(\.count).max() ?? 0
        let maxFocusMinutes = focusChartPoints.map(\.minutes).max() ?? 0

        state.filteredTaskCount = filteredTasks.count
        state.metrics = Metrics(
            chartPoints: chartPoints,
            focusChartPoints: focusChartPoints,
            totalDoneCount: completionDates.count,
            totalCanceledCount: canceledDates.count,
            totalFocusSeconds: totalFocusSeconds,
            averageFocusSecondsPerDay: averageFocusSecondsPerDay,
            activeRoutineCount: filteredTasks.filter { !$0.isArchived(referenceDate: now, calendar: calendar) }.count,
            archivedRoutineCount: filteredTasks.filter { $0.isArchived(referenceDate: now, calendar: calendar) }.count,
            totalCount: totalCount,
            averagePerDay: averagePerDay,
            highlightedBusiestDay: (busiestDay?.count ?? 0) > 0 ? busiestDay : nil,
            highlightedFocusDay: (busiestFocusDay?.seconds ?? 0) > 0 ? busiestFocusDay : nil,
            activeDayCount: chartPoints.filter { $0.count > 0 }.count,
            focusActiveDayCount: focusChartPoints.filter { $0.seconds > 0 }.count,
            chartUpperBound: Double(max(maxCount, Int(ceil(averagePerDay))) + 1),
            focusChartUpperBound: max(10, ceil(max(maxFocusMinutes, averageFocusSecondsPerDay / 60)) + 5),
            sparklinePoints: sparklinePoints,
            sparklineMaxCount: max(sparklinePoints.map(\.count).max() ?? 0, 1),
            xAxisDates: makeXAxisDates(from: chartPoints, for: state.selectedRange, calendar: calendar)
        )
    }

    private func sampledSparklinePoints(
        from chartPoints: [DoneChartPoint],
        for range: DoneChartRange
    ) -> [DoneChartPoint] {
        let targetCount: Int

        switch range {
        case .week:
            targetCount = 7
        case .month:
            targetCount = 15
        case .year:
            targetCount = 24
        }

        guard chartPoints.count > targetCount, targetCount > 1 else {
            return chartPoints
        }

        let step = Double(chartPoints.count - 1) / Double(targetCount - 1)

        return (0..<targetCount).map { index in
            let pointIndex = min(Int((Double(index) * step).rounded()), chartPoints.count - 1)
            return chartPoints[pointIndex]
        }
    }

    private func makeXAxisDates(
        from chartPoints: [DoneChartPoint],
        for range: DoneChartRange,
        calendar: Calendar
    ) -> [Date] {
        switch range {
        case .week:
            return chartPoints.map(\.date)

        case .month:
            return chartPoints.enumerated().compactMap { index, point in
                if index == 0 || index == chartPoints.count - 1 || index.isMultiple(of: 5) {
                    return point.date
                }
                return nil
            }

        case .year:
            let firstDate = chartPoints.first?.date
            let lastDate = chartPoints.last?.date

            return chartPoints.compactMap { point in
                let day = calendar.component(.day, from: point.date)
                if point.date == firstDate || point.date == lastDate || day == 1 {
                    return point.date
                }
                return nil
            }
        }
    }
}

private struct StatsTaskQueryDisplay: HomeTaskListDisplay {
    let taskID: UUID
    let name: String
    let emoji: String
    let notes: String?
    let placeID: UUID?
    let placeName: String?
    let tags: [String]
    let interval: Int
    let recurrenceRule: RoutineRecurrenceRule
    let scheduleMode: RoutineScheduleMode
    let createdAt: Date?
    let lastDone: Date?
    let dueDate: Date?
    let priority: RoutineTaskPriority
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let pressure: RoutineTaskPressure
    let scheduleAnchor: Date?
    let pausedAt: Date?
    let pinnedAt: Date?
    let daysUntilDue: Int
    let isOneOffTask: Bool
    let isCompletedOneOff: Bool
    let isCanceledOneOff: Bool
    let isDoneToday: Bool
    let isPaused: Bool
    let isPinned: Bool
    let isInProgress: Bool
    let completedChecklistItemCount: Int
    let manualSectionOrders: [String: Int]
    let todoState: TodoState?

    init(task: RoutineTask, referenceDate: Date, calendar: Calendar) {
        let dueDate = RoutineDateMath.dueDate(for: task, referenceDate: referenceDate, calendar: calendar)

        self.taskID = task.id
        self.name = task.name ?? "Untitled"
        self.emoji = CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "•"
        self.notes = CalendarTaskImportSupport.displayNotes(from: task.notes)
        self.placeID = task.placeID
        self.placeName = nil
        self.tags = task.tags
        self.interval = Int(task.interval)
        self.recurrenceRule = task.recurrenceRule
        self.scheduleMode = task.scheduleMode
        self.createdAt = task.createdAt
        self.lastDone = task.lastDone
        self.dueDate = dueDate
        self.priority = task.priority
        self.importance = task.importance
        self.urgency = task.urgency
        self.pressure = task.pressure
        self.scheduleAnchor = task.scheduleAnchor
        self.pausedAt = task.pausedAt
        self.pinnedAt = task.pinnedAt
        self.daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0
        self.isOneOffTask = task.isOneOffTask
        self.isCompletedOneOff = task.isCompletedOneOff
        self.isCanceledOneOff = task.isCanceledOneOff
        self.isDoneToday = task.lastDone.map { calendar.isDate($0, inSameDayAs: referenceDate) } ?? false
        self.isPaused = task.isPaused
        self.isPinned = task.isPinned
        self.isInProgress = task.isInProgress
        self.completedChecklistItemCount = task.completedChecklistItemCount
        self.manualSectionOrders = task.manualSectionOrders
        self.todoState = task.todoState
    }
}
