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
        StatsTaskTypeMatrixFilterSupport.matchesTaskType(
            task,
            taskTypeFilter: taskTypeFilter
        )
    }

    private func matchesImportanceUrgency(_ task: RoutineTask) -> Bool {
        StatsTaskTypeMatrixFilterSupport.matchesImportanceUrgency(
            task,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter
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
