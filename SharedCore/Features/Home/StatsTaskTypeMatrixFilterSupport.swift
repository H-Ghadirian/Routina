import Foundation

enum StatsTaskTypeMatrixFilterSupport {
    static func filteredTasks(
        _ tasks: [RoutineTask],
        taskTypeFilter: StatsTaskTypeFilter,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    ) -> [RoutineTask] {
        tasks
            .filter { matchesTaskType($0, taskTypeFilter: taskTypeFilter) }
            .filter {
                matchesImportanceUrgency(
                    $0,
                    selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter
                )
            }
    }

    static func matchesTaskType(
        _ task: RoutineTask,
        taskTypeFilter: StatsTaskTypeFilter
    ) -> Bool {
        switch taskTypeFilter {
        case .all:
            return true
        case .routines:
            return task.scheduleMode.taskType == .routine
        case .todos:
            return task.isOneOffTask
        case .records:
            return task.scheduleMode.taskType == .record
        }
    }

    static func matchesImportanceUrgency(
        _ task: RoutineTask,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    ) -> Bool {
        HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
            selectedImportanceUrgencyFilter,
            importance: task.importance,
            urgency: task.urgency
        )
    }
}
