import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var hasRestoredTemporaryViewState = false
        var home = HomeFeature.State()
        var goals = GoalsFeature.State()
        var timeline = TimelineFeature.State()
        var stats = StatsFeature.State()
        var settings = SettingsFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case homeFastFilterSelected(String)
        case home(HomeFeature.Action)
        case goals(GoalsFeature.Action)
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
        Scope(state: \.goals, action: \.goals) {
            GoalsFeature()
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
struct StatsFeature {
    typealias Metrics = StatsFeatureMetrics

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
        let derivedState = StatsFeatureDerivedStateBuilder.build(
            tasks: state.tasks,
            logs: state.logs,
            focusSessions: state.focusSessions,
            selectedRange: state.selectedRange,
            taskTypeFilter: state.taskTypeFilter,
            selectedImportanceUrgencyFilter: state.selectedImportanceUrgencyFilter,
            advancedQuery: state.advancedQuery,
            selectedTags: state.effectiveSelectedTags,
            includeTagMatchMode: state.includeTagMatchMode,
            excludedTags: state.excludedTags,
            excludeTagMatchMode: state.excludeTagMatchMode,
            tagColors: state.tagColors,
            referenceDate: now,
            calendar: calendar
        )
        state.availableTags = derivedState.availableTags
        state.setSelectedTags(derivedState.selectedTags)
        state.excludedTags = derivedState.excludedTags
        state.filteredTaskCount = derivedState.filteredTaskCount
        state.metrics = derivedState.metrics
    }
}
