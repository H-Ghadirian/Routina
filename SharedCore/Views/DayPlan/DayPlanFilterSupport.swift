import Foundation

struct DayPlanCalendarFilterState: Equatable {
    var showsPlannedTasks = true
    var showsAllDayTasks = true
    var showsTimelineSuggestions = true
    var showsAssumedDone = false
    var showsEvents = true
    var showsFocus = true
    var showsAway = true
    var showsSleep = true

    var hasActiveFilters: Bool {
        hasActiveFilters(availability: DayPlanCalendarFilterAvailability())
    }

    mutating func reset() {
        self = Self()
    }

    func normalized(availability: DayPlanCalendarFilterAvailability) -> Self {
        var copy = self
        if !availability.includesEvents {
            copy.showsEvents = true
        }
        if !availability.includesAway {
            copy.showsAway = true
        }
        if !availability.includesSleep {
            copy.showsSleep = true
        }
        return copy
    }

    func hasActiveFilters(availability: DayPlanCalendarFilterAvailability) -> Bool {
        normalized(availability: availability) != Self()
    }

    func hiddenLayerCount(availability: DayPlanCalendarFilterAvailability) -> Int {
        var count = 0
        if !showsPlannedTasks { count += 1 }
        if !showsAllDayTasks { count += 1 }
        if !showsTimelineSuggestions { count += 1 }
        if availability.includesEvents, !showsEvents { count += 1 }
        if !showsFocus { count += 1 }
        if availability.includesAway, !showsAway { count += 1 }
        if availability.includesSleep, !showsSleep { count += 1 }
        return count
    }

    func summaryText(availability: DayPlanCalendarFilterAvailability) -> String {
        let hiddenCount = hiddenLayerCount(availability: availability)
        if hiddenCount == 0 {
            return showsAssumedDone ? "Showing assumed done" : "Default layers visible"
        }

        let hiddenText = "\(hiddenCount) \(hiddenCount == 1 ? "layer" : "layers") hidden"
        return showsAssumedDone ? "\(hiddenText), showing assumed done" : hiddenText
    }

    func includesTimelineActivity(
        _ activity: DayPlanTimelineActivityBlock,
        includesAssumedDone: Bool = false
    ) -> Bool {
        includesAssumedDone || showsAssumedDone || !activity.source.isSyntheticAssumedDone
    }
}

struct DayPlanCalendarFilterAvailability: Equatable {
    var includesEvents = true
    var includesAway = true
    var includesSleep = true
}

struct DayPlanDayTaskListVisibilitySignature: Hashable {
    var showsPlannedTasks: Bool
    var showsAllDayTasks: Bool
    var showsTimelineSuggestions: Bool
    var showsAssumedDone: Bool
    var showsEvents: Bool
    var showsFocus: Bool
    var showsAway: Bool
    var showsSleep: Bool
    var includesEvents: Bool
    var includesAway: Bool
    var includesSleep: Bool
    var calendarSearchText: String
    var calendarTaskFilterCacheSeed: Int

    static let unfiltered = DayPlanDayTaskListVisibilitySignature(
        filters: DayPlanCalendarFilterState(),
        availability: DayPlanCalendarFilterAvailability(),
        calendarSearchText: "",
        calendarTaskFilterCacheSeed: 0
    )

    init(
        filters: DayPlanCalendarFilterState,
        availability: DayPlanCalendarFilterAvailability,
        calendarSearchText: String,
        calendarTaskFilterCacheSeed: Int
    ) {
        let normalizedFilters = filters.normalized(availability: availability)
        showsPlannedTasks = normalizedFilters.showsPlannedTasks
        showsAllDayTasks = normalizedFilters.showsAllDayTasks
        showsTimelineSuggestions = normalizedFilters.showsTimelineSuggestions
        showsAssumedDone = normalizedFilters.showsAssumedDone
        showsEvents = normalizedFilters.showsEvents
        showsFocus = normalizedFilters.showsFocus
        showsAway = normalizedFilters.showsAway
        showsSleep = normalizedFilters.showsSleep
        includesEvents = availability.includesEvents
        includesAway = availability.includesAway
        includesSleep = availability.includesSleep
        self.calendarSearchText = calendarSearchText
        self.calendarTaskFilterCacheSeed = calendarTaskFilterCacheSeed
    }
}

struct DayPlanVisibleBlockContext {
    var tasksByID: [UUID: RoutineTask]
    var canceledOneOffTaskIDs: Set<UUID>
    var hiddenOutcomeDayKeysByTaskID: [UUID: Set<String>]
    var activeFocusSessions: [FocusSession]
    private var logs: [RoutineLog]
    private var calendar: Calendar
    private var referenceDate: Date

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar,
        referenceDate: Date = Date(),
        activeFocusSessions: [FocusSession] = []
    ) {
        var tasksByID: [UUID: RoutineTask] = [:]
        var canceledOneOffTaskIDs: Set<UUID> = []
        var hiddenOutcomeDayKeysByTaskID: [UUID: Set<String>] = [:]

        for task in tasks {
            let taskID = task.id
            tasksByID[taskID] = task

            if task.isCanceledOneOff {
                canceledOneOffTaskIDs.insert(taskID)
            }

            if let canceledAt = task.canceledAt {
                hiddenOutcomeDayKeysByTaskID[taskID, default: []].insert(
                    DayPlanStorage.dayKey(for: canceledAt, calendar: calendar)
                )
            }

        }

        let canceledKind = RoutineLogKind.canceled.rawValue
        let missedKind = RoutineLogKind.missed.rawValue
        for log in logs {
            guard let timestamp = log.timestamp else {
                continue
            }

            if log.kindRawValue == canceledKind || log.kindRawValue == missedKind {
                hiddenOutcomeDayKeysByTaskID[log.taskID, default: []].insert(
                    DayPlanStorage.dayKey(for: timestamp, calendar: calendar)
                )
            }
        }

        self.tasksByID = tasksByID
        self.canceledOneOffTaskIDs = canceledOneOffTaskIDs
        self.hiddenOutcomeDayKeysByTaskID = hiddenOutcomeDayKeysByTaskID
        self.activeFocusSessions = activeFocusSessions
        self.logs = logs
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    func isHiddenTaskDay(taskID: UUID, dayKey: String) -> Bool {
        if hiddenOutcomeDayKeysByTaskID[taskID]?.contains(dayKey) == true {
            return true
        }

        guard let task = tasksByID[taskID],
            let day = Self.date(fromDayKey: dayKey, calendar: calendar)
        else {
            return false
        }

        if task.isArchived(referenceDate: day, calendar: calendar) {
            return true
        }

        return task.hidesAssumedDoneCalendarBlock
            && RoutineAssumedCompletion.isAssumedDone(
                for: task,
                on: day,
                referenceDate: referenceDate,
                logs: logs,
                calendar: calendar
            )
    }

    func isHiddenTaskDay(taskID: UUID, on date: Date) -> Bool {
        isHiddenTaskDay(
            taskID: taskID,
            dayKey: DayPlanStorage.dayKey(for: date, calendar: calendar)
        )
    }

    func correctedActiveFocusBlocks(_ blocks: [DayPlanBlock]) -> [DayPlanBlock] {
        DayPlanFocusSessionPlannerSync.correctedActiveCountUpFocusSegmentBlocks(
            blocks,
            activeFocusSessions: activeFocusSessions,
            referenceDate: referenceDate
        )
    }

    var referenceDayKey: String {
        DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
    }

    private static func date(fromDayKey dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

enum DayPlanScheduleViewVisibility {
    static func automaticTimelineBlocks(
        _ blocks: [DayPlanTimelineActivityBlock]
    ) -> [DayPlanTimelineActivityBlock] {
        []
    }

    static func allDayBlocks(
        _ blocks: [DayPlanAllDayBlock],
        context: DayPlanVisibleBlockContext? = nil
    ) -> [DayPlanAllDayBlock] {
        blocks.filter { block in
            guard !block.isCompletedActivity else { return false }
            guard let context,
                let taskID = block.taskID,
                !block.isEvent
            else {
                return true
            }
            return !context.isHiddenTaskDay(taskID: taskID, on: block.startDate)
        }
    }
}

enum DayPlanCalendarTaskPresentationFilter {
    static func matches(
        taskID: UUID?,
        title: String,
        emoji: String?,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool,
        normalizedSearchText: String
    ) -> Bool {
        let isSearchActive = !normalizedSearchText.isEmpty

        if let taskID {
            if matchingTaskIDs.contains(taskID) {
                return true
            }
            if allTaskIDs.contains(taskID) {
                return false
            }
            if taskID == FocusSession.unassignedTaskID {
                guard isSearchActive else { return true }
                return searchableText(title: title, emoji: emoji).contains(normalizedSearchText)
            }
        }

        guard isSearchActive else { return !isTaskFilterActive }
        return searchableText(title: title, emoji: emoji).contains(normalizedSearchText)
    }

    private static func searchableText(title: String, emoji: String?) -> String {
        [title, emoji ?? ""]
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

enum DayPlanCalendarTimelineActivityPresentationFilter {
    static func filteredBlocksByDayKey(
        _ blocksByDayKey: [String: [DayPlanTimelineActivityBlock]],
        filters: DayPlanCalendarFilterState,
        includesAssumedDone: Bool = false,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool,
        normalizedSearchText: String
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        blocksByDayKey.mapValues { blocks in
            blocks.filter { activity in
                matches(
                    activity,
                    filters: filters,
                    includesAssumedDone: includesAssumedDone,
                    matchingTaskIDs: matchingTaskIDs,
                    allTaskIDs: allTaskIDs,
                    isTaskFilterActive: isTaskFilterActive,
                    normalizedSearchText: normalizedSearchText
                )
            }
        }
    }

    static func matches(
        _ activity: DayPlanTimelineActivityBlock,
        filters: DayPlanCalendarFilterState,
        includesAssumedDone: Bool = false,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool,
        normalizedSearchText: String
    ) -> Bool {
        guard
            filters.includesTimelineActivity(
                activity,
                includesAssumedDone: includesAssumedDone
            )
        else {
            return false
        }

        return DayPlanCalendarTaskPresentationFilter.matches(
            taskID: activity.block.taskID,
            title: activity.block.titleSnapshot,
            emoji: activity.block.emojiSnapshot,
            matchingTaskIDs: matchingTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isTaskFilterActive,
            normalizedSearchText: normalizedSearchText
        )
    }
}

enum DayPlanTaskSorting {
    static func availableTasks(
        from tasks: [RoutineTask],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [RoutineTask] {
        tasks
            .filter {
                !$0.isCompletedOneOff
                    && !$0.isCanceledOneOff
                    && !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
            }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }

                if lhs.isOneOffTask != rhs.isOneOffTask {
                    return lhs.isOneOffTask
                }

                let lhsDeadline = lhs.deadline ?? .distantFuture
                let rhsDeadline = rhs.deadline ?? .distantFuture
                if lhsDeadline != rhsDeadline {
                    return lhsDeadline < rhsDeadline
                }

                return title(for: lhs).localizedCaseInsensitiveCompare(title(for: rhs)) == .orderedAscending
            }
    }

    static func filteredTasks(from tasks: [RoutineTask], query: String) -> [RoutineTask] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tasks }

        let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return tasks.filter { task in
            let searchableText = ([title(for: task), task.emoji ?? ""] + task.tags)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return searchableText.contains(normalizedQuery)
        }
    }

    static func title(for task: RoutineTask) -> String {
        let trimmed = RoutineTask.trimmedName(task.name) ?? ""
        return trimmed.isEmpty ? "Untitled task" : trimmed
    }
}
