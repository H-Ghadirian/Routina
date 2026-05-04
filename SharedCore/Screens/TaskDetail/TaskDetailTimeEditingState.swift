import Foundation

struct TaskDetailTimeEditingState {
    var editingLog: RoutineLog?
    var editingMinutes = TaskDetailTimeSpentPresentation.fallbackEntryMinutes
    var isEditingTaskTimeSpent = false

    mutating func beginEditingLog(_ log: RoutineLog, task: RoutineTask) {
        editingMinutes = TaskDetailTimeSpentPresentation.defaultLogEditMinutes(
            log: log,
            task: task
        )
        editingLog = log
    }

    mutating func dismissLog() {
        editingLog = nil
    }

    mutating func beginEditingTask(_ task: RoutineTask) {
        editingMinutes = TaskDetailTimeSpentPresentation.defaultTaskEditMinutes(task: task)
        isEditingTaskTimeSpent = true
    }

    mutating func dismissTask() {
        isEditingTaskTimeSpent = false
    }
}
