import ComposableArchitecture
import Foundation

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
                return .none
            case .onAppear:
                return .none
            default:
                return .none
            }
        }
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
        var selectedTag: String?
        var availableTags: [String] = []
        var filteredTaskCount: Int = 0
        var metrics = Metrics()
    }

    enum Action: Equatable {
        case setData(tasks: [RoutineTask], logs: [RoutineLog])
        case selectedRangeChanged(DoneChartRange)
        case selectedTagChanged(String?)
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

            case let .selectedTagChanged(tag):
                state.selectedTag = tag
                refreshDerivedState(&state)
                return .none
            }
        }
    }

    private func refreshDerivedState(_ state: inout State) {
        state.availableTags = RoutineTag.allTags(from: state.tasks.map(\.tags))
        if let selectedTag = state.selectedTag,
           !RoutineTag.contains(selectedTag, in: state.availableTags) {
            state.selectedTag = nil
        }

        let filteredTasks: [RoutineTask]
        let filteredLogs: [RoutineLog]
        if let tag = state.selectedTag {
            let taskIDsWithTag = Set(state.tasks.filter { $0.tags.contains(tag) }.map(\.id))
            filteredTasks = state.tasks.filter { $0.tags.contains(tag) }
            filteredLogs = state.logs.filter { taskIDsWithTag.contains($0.taskID) }
        } else {
            filteredTasks = state.tasks
            filteredLogs = state.logs
        }

        let completionDates = filteredLogs.compactMap(\.timestamp)
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
