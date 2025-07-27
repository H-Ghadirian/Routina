import Foundation

struct HomeTaskListSorter<Display: HomeTaskListDisplay> {
    static var pinnedManualOrderSectionKey: String { "pinned" }
    static var archivedManualOrderSectionKey: String { "archived" }

    var configuration: HomeTaskListFilteringConfiguration
    var metrics: HomeTaskListMetrics<Display>

    func sortedTasks(_ displays: [Display]) -> [Display] {
        displays.sorted(by: regularTaskSort)
    }

    func regularTaskSort(_ lhs: Display, _ rhs: Display) -> Bool {
        if let sortOrderComparison = taskListSortOrderResult(lhs, rhs) {
            return sortOrderComparison
        }

        if let manualOrderComparison = manualOrderSortResult(
            lhs,
            rhs,
            sectionKey: regularManualOrderSectionKey(for: lhs),
            otherSectionKey: regularManualOrderSectionKey(for: rhs)
        ) {
            return manualOrderComparison
        }

        if configuration.selectedFilter == .onMyMind, lhs.pressure != rhs.pressure {
            return lhs.pressure.sortOrder > rhs.pressure.sortOrder
        }

        let lhsOverdueDays = metrics.overdueDays(for: lhs)
        let rhsOverdueDays = metrics.overdueDays(for: rhs)
        if lhsOverdueDays != rhsOverdueDays {
            return lhsOverdueDays > rhsOverdueDays
        }

        let lhsUrgency = metrics.urgencyLevel(for: lhs)
        let rhsUrgency = metrics.urgencyLevel(for: rhs)
        if lhsUrgency != rhsUrgency {
            return lhsUrgency > rhsUrgency
        }

        if let dueDateComparison = dueDateSortResult(lhs, rhs) {
            return dueDateComparison
        }

        if lhs.priority != rhs.priority {
            return lhs.priority.sortOrder > rhs.priority.sortOrder
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    func taskListSortOrderResult(_ lhs: Display, _ rhs: Display) -> Bool? {
        switch configuration.taskListSortOrder {
        case .smart:
            return nil
        case .createdNewestFirst:
            return createdDateSortResult(lhs, rhs, newestFirst: true)
        case .createdOldestFirst:
            return createdDateSortResult(lhs, rhs, newestFirst: false)
        }
    }

    func createdDateSortResult(_ lhs: Display, _ rhs: Display, newestFirst: Bool) -> Bool? {
        switch (lhs.createdAt, rhs.createdAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return newestFirst ? lhsDate > rhsDate : lhsDate < rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return nil
        }
    }

    func archivedTaskSort(_ lhs: Display, _ rhs: Display) -> Bool {
        if let manualOrderComparison = manualOrderSortResult(
            lhs,
            rhs,
            sectionKey: Self.archivedManualOrderSectionKey,
            otherSectionKey: Self.archivedManualOrderSectionKey
        ) {
            return manualOrderComparison
        }

        if let sortOrderComparison = taskListSortOrderResult(lhs, rhs) {
            return sortOrderComparison
        }

        let lhsDate = lhs.pausedAt ?? lhs.lastDone ?? .distantPast
        let rhsDate = rhs.pausedAt ?? rhs.lastDone ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    func pinnedTaskSort(_ lhs: Display, _ rhs: Display) -> Bool {
        if let manualOrderComparison = manualOrderSortResult(
            lhs,
            rhs,
            sectionKey: Self.pinnedManualOrderSectionKey,
            otherSectionKey: Self.pinnedManualOrderSectionKey
        ) {
            return manualOrderComparison
        }

        if let sortOrderComparison = taskListSortOrderResult(lhs, rhs) {
            return sortOrderComparison
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

    func dueDateSortResult(_ lhs: Display, _ rhs: Display) -> Bool? {
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

    func regularManualOrderSectionKey(for task: Display) -> String {
        if task.isDoneToday {
            return "doneToday"
        }
        if metrics.overdueDays(for: task) > 0 {
            return "overdue"
        }
        if metrics.urgencyLevel(for: task) > 0 || metrics.isYellowUrgency(task) {
            return "dueSoon"
        }

        switch configuration.routineListSectioningMode {
        case .status:
            return "onTrack"
        case .deadlineDate:
            guard let sectionDate = metrics.sectionDateForDeadlineGrouping(for: task) else {
                return "onTrack"
            }
            return "onTrack:\(manualOrderDateKey(for: sectionDate))"
        }
    }

    private func manualOrderDateKey(for date: Date) -> String {
        let components = configuration.calendar.dateComponents([.year, .month, .day], from: configuration.calendar.startOfDay(for: date))
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func manualOrderSortResult(
        _ lhs: Display,
        _ rhs: Display,
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
