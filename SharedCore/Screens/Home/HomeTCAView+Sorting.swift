import Foundation

extension HomeTCAView {
    func sortedTasks(_ routineDisplays: [HomeFeature.RoutineDisplay]) -> [HomeFeature.RoutineDisplay] {
        taskListFiltering().sortedTasks(routineDisplays)
    }

    func regularTaskSort(
        _ task1: HomeFeature.RoutineDisplay,
        _ task2: HomeFeature.RoutineDisplay
    ) -> Bool {
        taskListFiltering().regularTaskSort(task1, task2)
    }

    func dueDateSortResult(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool? {
        taskListFiltering().dueDateSortResult(lhs, rhs)
    }

    func archivedTaskSort(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool {
        taskListFiltering().archivedTaskSort(lhs, rhs)
    }

    func pinnedTaskSort(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool {
        taskListFiltering().pinnedTaskSort(lhs, rhs)
    }

    func urgencyLevel(for task: HomeFeature.RoutineDisplay) -> Int {
        taskListFiltering().urgencyLevel(for: task)
    }
}
