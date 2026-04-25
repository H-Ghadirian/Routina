import SwiftUI
import ComposableArchitecture

extension HomeTCAView {
    func sortedTasks(_ routineDisplays: [HomeFeature.RoutineDisplay]) -> [HomeFeature.RoutineDisplay] {
        routineDisplays.sorted(by: regularTaskSort)
    }

    func regularTaskSort(
        _ task1: HomeFeature.RoutineDisplay,
        _ task2: HomeFeature.RoutineDisplay
    ) -> Bool {
        if let manualOrderComparison = manualOrderSortResult(task1, task2, sectionKey: regularManualOrderSectionKey(for: task1), otherSectionKey: regularManualOrderSectionKey(for: task2)) {
            return manualOrderComparison
        }

        if store.selectedFilter == .onMyMind, task1.pressure != task2.pressure {
            return task1.pressure.sortOrder > task2.pressure.sortOrder
        }

        let overdueDays1 = overdueDays(for: task1)
        let overdueDays2 = overdueDays(for: task2)

        if overdueDays1 != overdueDays2 {
            return overdueDays1 > overdueDays2
        }

        let urgency1 = urgencyLevel(for: task1)
        let urgency2 = urgencyLevel(for: task2)
        if urgency1 != urgency2 {
            return urgency1 > urgency2
        }

        if let dueDateComparison = dueDateSortResult(task1, task2) {
            return dueDateComparison
        }

        if task1.priority != task2.priority {
            return task1.priority.sortOrder > task2.priority.sortOrder
        }

        return task1.name.localizedCaseInsensitiveCompare(task2.name) == .orderedAscending
    }

    func dueDateSortResult(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool? {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return nil
        }
    }

    func archivedTaskSort(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool {
        if let manualOrderComparison = manualOrderSortResult(lhs, rhs, sectionKey: archivedManualOrderSectionKey, otherSectionKey: archivedManualOrderSectionKey) {
            return manualOrderComparison
        }

        let lhsDate = lhs.pausedAt ?? lhs.lastDone ?? .distantPast
        let rhsDate = rhs.pausedAt ?? rhs.lastDone ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    func pinnedTaskSort(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool {
        if let manualOrderComparison = manualOrderSortResult(lhs, rhs, sectionKey: pinnedManualOrderSectionKey, otherSectionKey: pinnedManualOrderSectionKey) {
            return manualOrderComparison
        }

        let lhsDate = lhs.pinnedAt ?? .distantPast
        let rhsDate = rhs.pinnedAt ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        if lhs.isPaused != rhs.isPaused {
            return !lhs.isPaused && rhs.isPaused
        }
        return lhs.isPaused && rhs.isPaused ? archivedTaskSort(lhs, rhs) : regularTaskSort(lhs, rhs)
    }

    func urgencyLevel(for task: HomeFeature.RoutineDisplay) -> Int {
        let dueIn = dueInDays(for: task)

        if dueIn < 0 { return 3 }
        if dueIn == 0 { return 2 }
        if dueIn == 1 { return 1 }
        return 0
    }

    private func manualOrderSortResult(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay,
        sectionKey: String,
        otherSectionKey: String
    ) -> Bool? {
        guard sectionKey == otherSectionKey else { return nil }

        let lhsOrder = lhs.manualSectionOrders[sectionKey]
        let rhsOrder = rhs.manualSectionOrders[sectionKey]

        switch (lhsOrder, rhsOrder) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return nil
        }
    }
}
