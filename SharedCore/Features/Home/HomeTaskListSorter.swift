import Foundation

struct HomeTaskListSorter<Display: HomeTaskListDisplay> {
    static var pinnedManualOrderSectionKey: String { "pinned" }
    static var plannedTodayManualOrderSectionKey: String { "plannedToday" }
    static var ungroupedManualOrderSectionKey: String { "tasks" }
    static var dailyManualOrderSectionKey: String { "daily" }
    static var archivedManualOrderSectionKey: String { "archived" }

    var configuration: HomeTaskListFilteringConfiguration
    var metrics: HomeTaskListMetrics<Display>

    func sortedTasks(_ displays: [Display]) -> [Display] {
        let sortKeys = cachedSortKeys(for: displays)
        return displays.sorted { lhs, rhs in
            regularTaskSort(lhs, rhs, sortKeys: sortKeys)
        }
    }

    func regularTaskSort(_ lhs: Display, _ rhs: Display) -> Bool {
        regularTaskSort(lhs, rhs, sortKeys: nil)
    }

    private func regularTaskSort(
        _ lhs: Display,
        _ rhs: Display,
        sortKeys: [UUID: HomeTaskListSortKey]?
    ) -> Bool {
        let lhsSortKey = sortKeys?[lhs.taskID]
        let rhsSortKey = sortKeys?[rhs.taskID]

        if let manualOrderComparison = manualOrderSortResult(
            lhs,
            rhs,
            sectionKey: regularManualOrderSectionKey(for: lhs, sortKey: lhsSortKey),
            otherSectionKey: regularManualOrderSectionKey(for: rhs, sortKey: rhsSortKey)
        ) {
            return manualOrderComparison
        }

        if let sortOrderComparison = taskListSortOrderResult(lhs, rhs) {
            return sortOrderComparison
        }

        if configuration.selectedFilter == .onMyMind, lhs.pressure != rhs.pressure {
            return lhs.pressure.sortOrder > rhs.pressure.sortOrder
        }

        let lhsOverdueDays = lhsSortKey?.overdueDays ?? metrics.overdueDays(for: lhs)
        let rhsOverdueDays = rhsSortKey?.overdueDays ?? metrics.overdueDays(for: rhs)
        if lhsOverdueDays != rhsOverdueDays {
            return lhsOverdueDays > rhsOverdueDays
        }

        let lhsUrgency = lhsSortKey?.urgencyLevel ?? metrics.urgencyLevel(for: lhs)
        let rhsUrgency = rhsSortKey?.urgencyLevel ?? metrics.urgencyLevel(for: rhs)
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

    func plannedTodayTaskSort(_ lhs: Display, _ rhs: Display) -> Bool {
        if let manualOrderComparison = manualOrderSortResult(
            lhs,
            rhs,
            sectionKey: Self.plannedTodayManualOrderSectionKey,
            otherSectionKey: Self.plannedTodayManualOrderSectionKey
        ) {
            return manualOrderComparison
        }

        return regularTaskSort(lhs, rhs)
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
        regularManualOrderSectionKey(for: task, sortKey: nil)
    }

    private func regularManualOrderSectionKey(
        for task: Display,
        sortKey: HomeTaskListSortKey?
    ) -> String {
        if task.isDailyRoutine {
            return Self.dailyManualOrderSectionKey
        }

        if configuration.routineListSectioningMode == .none {
            return Self.ungroupedManualOrderSectionKey
        }

        if configuration.routineListSectioningMode == .tags {
            return sortKey?.tagManualOrderSectionKey ?? task.taskListTagManualOrderSectionKey
        }

        if sortKey?.hasMissedExactTimedOccurrence ?? metrics.hasMissedExactTimedOccurrence(for: task) {
            return "missed"
        }
        if task.isDoneToday {
            return "doneToday"
        }
        if sortKey?.overdueDays ?? metrics.overdueDays(for: task) > 0 {
            return "overdue"
        }
        let urgencyLevel = sortKey?.urgencyLevel ?? metrics.urgencyLevel(for: task)
        let isYellowUrgency = sortKey?.isYellowUrgency ?? metrics.isYellowUrgency(task)
        if urgencyLevel > 0 || isYellowUrgency {
            return "dueSoon"
        }

        switch configuration.routineListSectioningMode {
        case .none:
            return Self.ungroupedManualOrderSectionKey
        case .status:
            return "onTrack"
        case .deadlineDate:
            guard let sectionDate = sortKey?.deadlineSectionDate ?? metrics.sectionDateForDeadlineGrouping(for: task) else {
                return "onTrack"
            }
            return "onTrack:\(manualOrderDateKey(for: sectionDate))"
        case .tags:
            return sortKey?.tagManualOrderSectionKey ?? task.taskListTagManualOrderSectionKey
        }
    }

    private func cachedSortKeys(for displays: [Display]) -> [UUID: HomeTaskListSortKey] {
        var sortKeys: [UUID: HomeTaskListSortKey] = [:]
        sortKeys.reserveCapacity(displays.count)

        let sectioningMode = configuration.routineListSectioningMode
        for task in displays {
            let overdueDays = metrics.overdueDays(for: task)
            let urgencyLevel = metrics.urgencyLevel(for: task)
            let isYellowUrgency = sectioningMode == .status || sectioningMode == .deadlineDate
                ? metrics.isYellowUrgency(task)
                : false
            let tagManualOrderSectionKey = sectioningMode == .tags
                ? HomeTaskListTagGrouping.descriptor(for: task).sectionKey
                : nil
            let deadlineSectionDate = sectioningMode == .deadlineDate
                ? metrics.sectionDateForDeadlineGrouping(for: task)
                : nil

            sortKeys[task.taskID] = HomeTaskListSortKey(
                hasMissedExactTimedOccurrence: metrics.hasMissedExactTimedOccurrence(for: task),
                overdueDays: overdueDays,
                urgencyLevel: urgencyLevel,
                isYellowUrgency: isYellowUrgency,
                tagManualOrderSectionKey: tagManualOrderSectionKey,
                deadlineSectionDate: deadlineSectionDate
            )
        }

        return sortKeys
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

private struct HomeTaskListSortKey {
    let hasMissedExactTimedOccurrence: Bool
    let overdueDays: Int
    let urgencyLevel: Int
    let isYellowUrgency: Bool
    let tagManualOrderSectionKey: String?
    let deadlineSectionDate: Date?
}
