import Foundation

struct StatsActiveItemsBreakdown {
    let routineCount: Int
    let todoCount: Int
    let recordCount: Int
    let openTodoCount: Int
    let completedTodoCount: Int
    let canceledTodoCount: Int
    let archivedCount: Int
    let activeCount: Int

    var matchingCount: Int {
        routineCount + todoCount + recordCount
    }

    init(
        tasks: [RoutineTask],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        let todoTasks = tasks.filter(\.isOneOffTask)
        let recordTasks = tasks.filter(\.isRecordTask)
        let archivedCount = tasks.filter {
            $0.isArchived(referenceDate: referenceDate, calendar: calendar)
        }.count

        self.routineCount = tasks.filter { $0.scheduleMode.taskType == .routine }.count
        self.todoCount = todoTasks.count
        self.recordCount = recordTasks.count
        self.openTodoCount = todoTasks.filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }.count
        self.completedTodoCount = todoTasks.filter(\.isCompletedOneOff).count
        self.canceledTodoCount = todoTasks.filter(\.isCanceledOneOff).count
        self.archivedCount = archivedCount
        self.activeCount = tasks.count - archivedCount
    }
}
