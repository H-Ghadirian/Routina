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
                 .timeline(.clearFilters),
                 .stats(.selectedRangeChanged),
                 .stats(.taskTypeFilterChanged),
                 .stats(.selectedTagChanged),
                 .stats(.excludedTagsChanged):
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
        state.stats.selectedRange = persistedState.statsSelectedRange
        state.stats.selectedTag = persistedState.statsSelectedTag
        state.stats.excludedTags = persistedState.statsExcludedTags
        if let rawValue = persistedState.statsTaskTypeFilterRawValue,
           let filter = StatsTaskTypeFilter(rawValue: rawValue) {
            state.stats.taskTypeFilter = filter
        }
    }

    private func resetTemporaryViewState(_ state: inout State) {
        state.home.taskListMode = .routines
        state.home.selectedFilter = .all
        state.home.selectedTag = nil
        state.home.excludedTags = []
        state.home.selectedManualPlaceFilterID = nil
        state.home.tabFilterSnapshots = [:]
        state.home.hideUnavailableRoutines = false
        state.home.isFilterSheetPresented = false
        state.home.selectedTimelineRange = .all
        state.home.selectedTimelineFilterType = .all
        state.home.selectedTimelineTag = nil
        state.home.statsSelectedRange = .week
        state.home.statsSelectedTag = nil

        state.timeline.selectedRange = .all
        state.timeline.filterType = .all
        state.timeline.selectedTag = nil
        state.timeline.isFilterSheetPresented = false
        state.timeline.availableTags = []
        state.timeline.groupedEntries = []

        state.stats.selectedRange = .week
        state.stats.selectedTag = nil
        state.stats.excludedTags = []
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
                homeTabFilterSnapshots: existing.homeTabFilterSnapshots,
                hideUnavailableRoutines: existing.hideUnavailableRoutines,
                homeSelectedTimelineRange: existing.homeSelectedTimelineRange,
                homeSelectedTimelineFilterType: existing.homeSelectedTimelineFilterType,
                homeSelectedTimelineTag: existing.homeSelectedTimelineTag,
                macHomeSidebarModeRawValue: existing.macHomeSidebarModeRawValue,
                macSelectedSettingsSectionRawValue: existing.macSelectedSettingsSectionRawValue,
                timelineSelectedRange: state.timeline.selectedRange,
                timelineFilterType: state.timeline.filterType,
                timelineSelectedTag: state.timeline.selectedTag,
                statsSelectedRange: state.stats.selectedRange,
                statsSelectedTag: state.stats.selectedTag,
                statsExcludedTags: state.stats.excludedTags,
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
        var isFilterSheetPresented: Bool = false
        var availableTags: [String] = []
        var groupedEntries: [TimelineSection] = []

        var hasActiveFilters: Bool {
            selectedRange != .all || filterType != .all || selectedTag != nil
        }
    }

    enum Action: Equatable {
        case setData(tasks: [RoutineTask], logs: [RoutineLog])
        case selectedRangeChanged(TimelineRange)
        case filterTypeChanged(TimelineFilterType)
        case selectedTagChanged(String?)
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

            case let .setFilterSheet(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .clearFilters:
                state.selectedRange = .all
                state.filterType = .all
                state.selectedTag = nil
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
        state.availableTags = TimelineLogic.availableTags(from: baseEntries)
        if let selectedTag = state.selectedTag,
           !RoutineTag.contains(selectedTag, in: state.availableTags) {
            state.selectedTag = nil
        }

        let entries = baseEntries.filter { entry in
            TimelineLogic.matchesSelectedTag(state.selectedTag, in: entry.tags)
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
        var selectedTag: String?
        var excludedTags: Set<String> = []
        var availableTags: [String] = []
        var filteredTaskCount: Int = 0
        var metrics = Metrics()
    }

    enum Action: Equatable {
        case setData(tasks: [RoutineTask], logs: [RoutineLog])
        case selectedRangeChanged(DoneChartRange)
        case taskTypeFilterChanged(StatsTaskTypeFilter)
        case selectedTagChanged(String?)
        case excludedTagsChanged(Set<String>)
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

            case let .taskTypeFilterChanged(filter):
                state.taskTypeFilter = filter
                refreshDerivedState(&state)
                return .none

            case let .selectedTagChanged(tag):
                state.selectedTag = tag
                refreshDerivedState(&state)
                return .none

            case let .excludedTagsChanged(tags):
                state.excludedTags = tags
                refreshDerivedState(&state)
                return .none
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

        state.availableTags = RoutineTag.allTags(from: tasksMatchingTypeFilter.map(\.tags))
        if let selectedTag = state.selectedTag,
           !RoutineTag.contains(selectedTag, in: state.availableTags) {
            state.selectedTag = nil
        }
        let availableExcludeTags = state.availableTags.filter { tag in
            state.selectedTag.map { !RoutineTag.contains($0, in: [tag]) } ?? true
        }
        state.excludedTags = state.excludedTags.filter { RoutineTag.contains($0, in: availableExcludeTags) }

        let filteredTasks: [RoutineTask]
        let filteredLogs: [RoutineLog]
        let includeFilteredTasks: [RoutineTask]
        if let tag = state.selectedTag {
            includeFilteredTasks = tasksMatchingTypeFilter.filter { RoutineTag.contains(tag, in: $0.tags) }
        } else {
            includeFilteredTasks = tasksMatchingTypeFilter
        }

        filteredTasks = includeFilteredTasks.filter { task in
            !state.excludedTags.contains { excludedTag in
                RoutineTag.contains(excludedTag, in: task.tags)
            }
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
            activeRoutineCount: filteredTasks.filter { !$0.isPaused }.count,
            archivedRoutineCount: filteredTasks.filter(\.isPaused).count,
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
