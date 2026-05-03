struct StatsTaskFilterResolver {
    let taskTypeFilter: StatsTaskTypeFilter
    let selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludedTags: Set<String>
    let excludeTagMatchMode: RoutineTagMatchMode

    func filteredTasks(from tasks: [RoutineTask]) -> [RoutineTask] {
        tasks
            .filter(matchesTaskType)
            .filter(matchesImportanceUrgency)
            .filter(matchesSelectedTags)
            .filter(matchesExcludedTags)
    }

    private func matchesTaskType(_ task: RoutineTask) -> Bool {
        switch taskTypeFilter {
        case .all:
            return true
        case .routines:
            return !task.isOneOffTask
        case .todos:
            return task.isOneOffTask
        }
    }

    private func matchesImportanceUrgency(_ task: RoutineTask) -> Bool {
        HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
            selectedImportanceUrgencyFilter,
            importance: task.importance,
            urgency: task.urgency
        )
    }

    private func matchesSelectedTags(_ task: RoutineTask) -> Bool {
        HomeDisplayFilterSupport.matchesSelectedTags(
            selectedTags,
            mode: includeTagMatchMode,
            in: task.tags
        )
    }

    private func matchesExcludedTags(_ task: RoutineTask) -> Bool {
        HomeDisplayFilterSupport.matchesExcludedTags(
            excludedTags,
            mode: excludeTagMatchMode,
            in: task.tags
        )
    }
}
