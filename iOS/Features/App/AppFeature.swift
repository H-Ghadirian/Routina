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
        var home = HomeFeature.State()
        var timeline = TimelineFeature.State()
        var stats = StatsFeature.State()
        var settings = SettingsFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case timeline(TimelineFeature.Action)
        case stats(StatsFeature.Action)
        case settings(SettingsFeature.Action)
        case onAppear
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
            case .onAppear:
                applyTemporaryViewState(appSettingsClient.temporaryViewState(), to: &state)
                return .none
            case .settings(.resetTemporaryViewStateTapped):
                let timelineTasks = state.timeline.tasks
                let timelineLogs = state.timeline.logs
                let statsTasks = state.stats.tasks
                let statsLogs = state.stats.logs
                resetTemporaryViewState(&state)
                persistTemporaryViewState(state)
                return .merge(
                    .send(.timeline(.setData(tasks: timelineTasks, logs: timelineLogs))),
                    .send(.stats(.setData(tasks: statsTasks, logs: statsLogs)))
                )
            case .timeline(.selectedRangeChanged),
                 .timeline(.filterTypeChanged),
                 .timeline(.selectedTagChanged),
                 .timeline(.selectedImportanceUrgencyFilterChanged),
                 .timeline(.excludedTagsChanged),
                 .timeline(.clearFilters),
                 .stats(.selectedRangeChanged),
                 .stats(.taskTypeFilterChanged),
                 .stats(.selectedTagChanged),
                 .stats(.selectedImportanceUrgencyFilterChanged),
                 .stats(.excludedTagsChanged),
                 .stats(.clearFilters):
                persistTemporaryViewState(state)
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
        state.timeline.selectedTag = persistedState.timelineSelectedTag
        state.timeline.selectedImportanceUrgencyFilter = persistedState.timelineSelectedImportanceUrgencyFilter
        state.stats.selectedRange = persistedState.statsSelectedRange
        state.stats.selectedTag = persistedState.statsSelectedTag
        state.stats.excludedTags = persistedState.statsExcludedTags
        state.stats.selectedImportanceUrgencyFilter = persistedState.statsSelectedImportanceUrgencyFilter
        if let rawValue = persistedState.statsTaskTypeFilterRawValue,
           let filter = StatsTaskTypeFilter(rawValue: rawValue) {
            state.stats.taskTypeFilter = filter
        }
    }

    private func resetTemporaryViewState(_ state: inout State) {
        state.home.taskListMode = .all
        state.home.selectedFilter = .all
        state.home.selectedTag = nil
        state.home.excludedTags = []
        state.home.selectedManualPlaceFilterID = nil
        state.home.selectedImportanceUrgencyFilter = nil
        state.home.tabFilterSnapshots = [:]
        state.home.hideUnavailableRoutines = false
        state.home.isFilterSheetPresented = false
        state.home.selectedTimelineRange = .all
        state.home.selectedTimelineFilterType = .all
        state.home.selectedTimelineTag = nil
        state.home.selectedTimelineImportanceUrgencyFilter = nil
        state.home.statsSelectedRange = .week
        state.home.statsSelectedTag = nil

        state.timeline.selectedRange = .all
        state.timeline.filterType = .all
        state.timeline.selectedTag = nil
        state.timeline.selectedImportanceUrgencyFilter = nil
        state.timeline.excludedTags = []
        state.timeline.isFilterSheetPresented = false
        state.timeline.availableTags = []
        state.timeline.groupedEntries = []

        state.stats.selectedRange = .week
        state.stats.isFilterSheetPresented = false
        state.stats.selectedTag = nil
        state.stats.excludedTags = []
        state.stats.selectedImportanceUrgencyFilter = nil
        state.stats.taskTypeFilter = .all
    }

    private func persistTemporaryViewState(_ state: State) {
        let existing = appSettingsClient.temporaryViewState() ?? .default
        appSettingsClient.setTemporaryViewState(
            TemporaryViewState(
                selectedAppTabRawValue: state.selectedTab.rawValue,
                homeTaskListModeRawValue: existing.homeTaskListModeRawValue,
                homeSelectedFilter: existing.homeSelectedFilter,
                homeSelectedTag: existing.homeSelectedTag,
                homeExcludedTags: existing.homeExcludedTags,
                homeSelectedManualPlaceFilterID: existing.homeSelectedManualPlaceFilterID,
                homeSelectedImportanceUrgencyFilter: existing.homeSelectedImportanceUrgencyFilter,
                homeTabFilterSnapshots: existing.homeTabFilterSnapshots,
                hideUnavailableRoutines: existing.hideUnavailableRoutines,
                homeSelectedTimelineRange: existing.homeSelectedTimelineRange,
                homeSelectedTimelineFilterType: existing.homeSelectedTimelineFilterType,
                homeSelectedTimelineTag: existing.homeSelectedTimelineTag,
                homeSelectedTimelineImportanceUrgencyFilter: existing.homeSelectedTimelineImportanceUrgencyFilter,
                macHomeSidebarModeRawValue: existing.macHomeSidebarModeRawValue,
                macSelectedSettingsSectionRawValue: existing.macSelectedSettingsSectionRawValue,
                timelineSelectedRange: state.timeline.selectedRange,
                timelineFilterType: state.timeline.filterType,
                timelineSelectedTag: state.timeline.selectedTag,
                timelineSelectedImportanceUrgencyFilter: state.timeline.selectedImportanceUrgencyFilter,
                statsSelectedRange: state.stats.selectedRange,
                statsSelectedTag: state.stats.selectedTag,
                statsExcludedTags: state.stats.excludedTags,
                statsSelectedImportanceUrgencyFilter: state.stats.selectedImportanceUrgencyFilter,
                statsTaskTypeFilterRawValue: state.stats.taskTypeFilter.rawValue
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
        var excludedTags: Set<String> = []
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var isFilterSheetPresented: Bool = false
        var availableTags: [String] = []
        var groupedEntries: [TimelineSection] = []

        var hasActiveFilters: Bool {
            selectedRange != .all || filterType != .all || selectedTag != nil || !excludedTags.isEmpty || selectedImportanceUrgencyFilter != nil
        }
    }

    enum Action: Equatable {
        case setData(tasks: [RoutineTask], logs: [RoutineLog])
        case selectedRangeChanged(TimelineRange)
        case filterTypeChanged(TimelineFilterType)
        case selectedTagChanged(String?)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case excludedTagsChanged(Set<String>)
        case setFilterSheet(Bool)
        case clearFilters
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setData(tasks, logs):
                state.tasks = tasks
                state.logs = logs
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
                state.selectedTag = tag
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

            case let .setFilterSheet(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .clearFilters:
                state.selectedRange = .all
                state.filterType = .all
                state.selectedTag = nil
                state.selectedImportanceUrgencyFilter = nil
                state.excludedTags = []
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
        if let selectedTag = state.selectedTag,
           !RoutineTag.contains(selectedTag, in: state.availableTags) {
            state.selectedTag = nil
        }
        state.excludedTags = state.excludedTags.filter { RoutineTag.contains($0, in: state.availableTags) }

        let entries = importanceUrgencyFilteredEntries.filter { entry in
            TimelineLogic.matchesSelectedTag(state.selectedTag, in: entry.tags)
                && !state.excludedTags.contains { RoutineTag.contains($0, in: entry.tags) }
        }
        state.groupedEntries = TimelineLogic.groupedByDay(entries: entries, calendar: calendar)
            .map { TimelineSection(date: $0.date, entries: $0.entries) }
    }
}

@Reducer
struct StatsFeature {
    struct Metrics: Equatable {
        var chartPoints: [DoneChartPoint] = []
        var totalDoneCount: Int = 0
        var totalCanceledCount: Int = 0
        var activeRoutineCount: Int = 0
        var archivedRoutineCount: Int = 0
        var totalCount: Int = 0
        var averagePerDay: Double = 0
        var highlightedBusiestDay: DoneChartPoint?
        var activeDayCount: Int = 0
        var chartUpperBound: Double = 1
        var sparklinePoints: [DoneChartPoint] = []
        var sparklineMaxCount: Int = 1
        var xAxisDates: [Date] = []
    }

    @ObservableState
    struct State: Equatable {
        var tasks: [RoutineTask] = []
        var logs: [RoutineLog] = []
        var selectedRange: DoneChartRange = .week
        var taskTypeFilter: StatsTaskTypeFilter = .all
        var isFilterSheetPresented: Bool = false
        var selectedTag: String?
        var excludedTags: Set<String> = []
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var availableTags: [String] = []
        var filteredTaskCount: Int = 0
        var metrics = Metrics()
        var gitHubConnection = GitHubConnectionStatus.disconnected
        var gitHubStats: GitHubStatsSnapshot?
        var isGitHubStatsLoading: Bool = false
        var gitHubStatsErrorMessage: String?

        var hasActiveFilters: Bool {
            selectedRange != .week || taskTypeFilter != .all || selectedTag != nil || !excludedTags.isEmpty || selectedImportanceUrgencyFilter != nil
        }
    }

    enum Action: Equatable {
        case setData(tasks: [RoutineTask], logs: [RoutineLog])
        case onAppear
        case selectedRangeChanged(DoneChartRange)
        case taskTypeFilterChanged(StatsTaskTypeFilter)
        case selectedTagChanged(String?)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case excludedTagsChanged(Set<String>)
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

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setData(tasks, logs):
                state.tasks = tasks
                state.logs = logs
                refreshDerivedState(&state)
                return .none

            case .onAppear:
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
                guard state.gitHubConnection.isConnected else {
                    return .none
                }
                return refreshGitHubStatsEffect(state: &state, skipGitLab: true)

            case let .taskTypeFilterChanged(filter):
                state.taskTypeFilter = filter
                refreshDerivedState(&state)
                return .none

            case let .selectedTagChanged(tag):
                state.selectedTag = tag
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

            case let .setFilterSheet(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .gitHubStatsRefreshRequested:
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
                state.selectedTag = nil
                state.excludedTags = []
                state.selectedImportanceUrgencyFilter = nil
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

        state.availableTags = RoutineTag.allTags(from: tasksMatchingMatrixFilter.map(\.tags))
        if let selectedTag = state.selectedTag,
           !RoutineTag.contains(selectedTag, in: state.availableTags) {
            state.selectedTag = nil
        }
        state.excludedTags = state.excludedTags.filter { RoutineTag.contains($0, in: state.availableTags) }

        let filteredTasks: [RoutineTask]
        let filteredLogs: [RoutineLog]
        let includeFilteredTasks = tasksMatchingMatrixFilter.filter { task in
            guard let tag = state.selectedTag else { return true }
            return RoutineTag.contains(tag, in: task.tags)
        }
        filteredTasks = includeFilteredTasks.filter { task in
            !state.excludedTags.contains { RoutineTag.contains($0, in: task.tags) }
        }
        let filteredTaskIDs = Set(filteredTasks.map(\.id))
        filteredLogs = state.logs.filter { filteredTaskIDs.contains($0.taskID) }

        let completionDates = filteredLogs
            .filter { $0.kind == .completed }
            .compactMap(\.timestamp)
        let canceledDates = filteredLogs
            .filter { $0.kind == .canceled }
            .compactMap(\.timestamp)
        let chartPoints = RoutineCompletionStats.points(
            for: state.selectedRange,
            timestamps: completionDates,
            referenceDate: now,
            calendar: calendar
        )
        let totalCount = RoutineCompletionStats.totalCount(in: chartPoints)
        let averagePerDay = RoutineCompletionStats.averageCount(in: chartPoints)
        let busiestDay = RoutineCompletionStats.busiestDay(in: chartPoints)
        let sparklinePoints = sampledSparklinePoints(
            from: chartPoints,
            for: state.selectedRange
        )
        let maxCount = chartPoints.map(\.count).max() ?? 0

        state.filteredTaskCount = filteredTasks.count
        state.metrics = Metrics(
            chartPoints: chartPoints,
            totalDoneCount: completionDates.count,
            totalCanceledCount: canceledDates.count,
            activeRoutineCount: filteredTasks.filter { !$0.isArchived(referenceDate: now, calendar: calendar) }.count,
            archivedRoutineCount: filteredTasks.filter { $0.isArchived(referenceDate: now, calendar: calendar) }.count,
            totalCount: totalCount,
            averagePerDay: averagePerDay,
            highlightedBusiestDay: (busiestDay?.count ?? 0) > 0 ? busiestDay : nil,
            activeDayCount: chartPoints.filter { $0.count > 0 }.count,
            chartUpperBound: Double(max(maxCount, Int(ceil(averagePerDay))) + 1),
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
