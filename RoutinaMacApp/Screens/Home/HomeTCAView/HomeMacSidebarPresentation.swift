import Foundation

struct HomeMacSidebarPresentation {
    let mode: HomeFeature.MacSidebarMode
    let taskListMode: HomeFeature.TaskListMode
    let isFilterDetailPresented: Bool
    let boardScopeTitle: String
    let selectedTimelineRange: TimelineRange
    let selectedTimelineFilterType: TimelineFilterType
    let selectedTimelineTags: Set<String>
    let selectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let selectedTimelineExcludedTags: Set<String>
    let selectedFilter: RoutineListFilter
    let hasActiveOptionalFilters: Bool

    var isTimelineMode: Bool { mode == .timeline }
    var isStatsMode: Bool { mode == .stats || mode == .adventure }
    var isSettingsMode: Bool { mode == .settings }
    var isRoutinesMode: Bool { mode == .routines }
    var isBoardMode: Bool { mode == .board }
    var isGoalsMode: Bool { mode == .goals }
    var isAdventureMode: Bool { mode == .adventure }
    var isAddTaskMode: Bool { mode == .addTask }

    var navigationTitle: String {
        if isFilterDetailPresented {
            return filterDetailNavigationTitle
        }

        switch mode {
        case .routines:
            return taskListMode.sidebarTitle
        case .board:
            return boardScopeTitle
        case .goals:
            return "Goals"
        case .adventure:
            return "Stats"
        case .timeline:
            return "Timeline"
        case .stats:
            return "Stats"
        case .settings:
            return "Settings"
        case .addTask:
            return "Add Task"
        }
    }

    var hasCustomFiltersApplied: Bool {
        if mode == .timeline {
            return selectedTimelineFilterType != .all
                || !selectedTimelineTags.isEmpty
                || selectedTimelineImportanceUrgencyFilter != nil
                || !selectedTimelineExcludedTags.isEmpty
        }
        if mode == .goals { return false }
        if mode == .adventure { return false }
        if mode == .stats { return false }
        return taskListMode != .all || selectedFilter != .all || hasActiveOptionalFilters
    }

    private var filterDetailNavigationTitle: String {
        switch mode {
        case .routines:
            return taskListMode.filterTitle
        case .board:
            return "Filter Board"
        case .goals:
            return "Goals"
        case .adventure:
            return "Stats"
        case .timeline:
            return "Filter Timeline"
        case .stats:
            return "Stats"
        case .settings:
            return "Settings"
        case .addTask:
            return "Add Task"
        }
    }
}

private extension HomeFeature.TaskListMode {
    var sidebarTitle: String {
        switch self {
        case .all:
            return "All"
        case .routines:
            return "Routines"
        case .todos:
            return "Todos"
        case .records:
            return "Tracking"
        }
    }

    var filterTitle: String {
        switch self {
        case .all:
            return "Filter All"
        case .routines:
            return "Filter Routines"
        case .todos:
            return "Filter Todos"
        case .records:
            return "Filter Tracking"
        }
    }
}
