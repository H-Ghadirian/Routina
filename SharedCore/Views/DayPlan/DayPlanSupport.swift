import Combine
import Foundation

struct DayPlanCalendarFilterState: Equatable {
    var showsPlannedTasks = true
    var showsAllDayTasks = true
    var showsTimelineSuggestions = true
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
        let count = hiddenLayerCount(availability: availability)
        return count == 0 ? "All layers visible" : "\(count) \(count == 1 ? "layer" : "layers") hidden"
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

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar,
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
            guard log.kindRawValue == canceledKind || log.kindRawValue == missedKind,
                  let timestamp = log.timestamp else {
                continue
            }

            hiddenOutcomeDayKeysByTaskID[log.taskID, default: []].insert(
                DayPlanStorage.dayKey(for: timestamp, calendar: calendar)
            )
        }

        self.tasksByID = tasksByID
        self.canceledOneOffTaskIDs = canceledOneOffTaskIDs
        self.hiddenOutcomeDayKeysByTaskID = hiddenOutcomeDayKeysByTaskID
        self.activeFocusSessions = activeFocusSessions
    }
}

enum DayPlanTaskSorting {
    static func availableTasks(from tasks: [RoutineTask]) -> [RoutineTask] {
        tasks
            .filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
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

enum DayPlanVisibleBlocks {
    static func blocks(
        _ blocks: [DayPlanBlock],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar,
        activeFocusSessions: [FocusSession] = []
    ) -> [DayPlanBlock] {
        Self.blocks(
            blocks,
            context: DayPlanVisibleBlockContext(
                tasks: tasks,
                logs: logs,
                calendar: calendar,
                activeFocusSessions: activeFocusSessions
            )
        )
    }

    static func blocks(
        _ blocks: [DayPlanBlock],
        context: DayPlanVisibleBlockContext
    ) -> [DayPlanBlock] {
        guard !blocks.isEmpty else { return [] }

        let activeCountUpSegmentBlockIDs = activeCountUpCurrentSegmentBlockIDs(
            blocks,
            activeFocusSessions: context.activeFocusSessions
        )

        return blocks.filter { block in
            if activeCountUpSegmentBlockIDs.contains(block.id) {
                return false
            }

            guard context.tasksByID[block.taskID] != nil else { return true }
            guard !context.canceledOneOffTaskIDs.contains(block.taskID) else { return false }
            return context.hiddenOutcomeDayKeysByTaskID[block.taskID]?.contains(block.dayKey) != true
        }
    }

    private static func activeCountUpCurrentSegmentBlockIDs(
        _ blocks: [DayPlanBlock],
        activeFocusSessions: [FocusSession]
    ) -> Set<UUID> {
        Set(activeFocusSessions.compactMap { session in
            guard session.plannedDurationSeconds <= 0,
                  session.completedAt == nil,
                  session.abandonedAt == nil,
                  session.pausedAt == nil,
                  session.startedAt != nil,
                  session.isTaskFocus || session.isTagFocus else {
                return nil
            }

            return DayPlanFocusSessionPlannerSync.latestFocusSegmentBlock(
                in: blocks,
                for: session
            )?.id ?? session.id
        })
    }
}

struct DayPlanDayTaskListItem: Identifiable, Equatable {
    enum Placement: Equatable {
        case allDay
        case timed(startMinute: Int, durationMinutes: Int)
    }

    var id: String
    var taskID: UUID
    var blockID: UUID?
    var title: String
    var emoji: String?
    var placement: Placement
}

enum DayPlanDayTaskListPresentation {
    static func items(
        on date: Date,
        timedBlocks: [DayPlanBlock],
        allDayBlocks: [DayPlanAllDayBlock],
        plannedDateTasks: [RoutineTask] = [],
        calendar: Calendar,
        visibilityCache: DayPlanPlannedDateTaskVisibilityCache? = nil
    ) -> [DayPlanDayTaskListItem] {
        let allDayItems = allDayBlocks
            .enumerated()
            .compactMap { offset, allDayBlock -> DayPlanDayTaskListItem? in
                guard let taskID = allDayBlock.taskID,
                      !allDayBlock.isEvent,
                      allDayBlockIntersects(allDayBlock, date: date, calendar: calendar) else {
                    return nil
                }

                return DayPlanDayTaskListItem(
                    id: "all-day-\(taskID.uuidString)-\(offset)",
                    taskID: taskID,
                    blockID: nil,
                    title: allDayBlock.title,
                    emoji: allDayBlock.emoji,
                    placement: .allDay
                )
            }
            .sorted { lhs, rhs in
                let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if titleComparison != .orderedSame {
                    return titleComparison == .orderedAscending
                }
                return lhs.id < rhs.id
            }

        let plannedTaskIDs = Set(allDayItems.map(\.taskID) + timedBlocks.map(\.taskID))
        let plannedDateItems = plannedDateTasks
            .compactMap { task -> DayPlanDayTaskListItem? in
                guard !plannedTaskIDs.contains(task.id),
                      isVisiblePlannedDateTask(
                        task,
                        on: date,
                        calendar: calendar,
                        visibilityCache: visibilityCache
                      ) else {
                    return nil
                }

                return DayPlanDayTaskListItem(
                    id: "planned-date-\(task.id.uuidString)",
                    taskID: task.id,
                    blockID: nil,
                    title: DayPlanTaskSorting.title(for: task),
                    emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                    placement: .allDay
                )
            }
            .sorted { lhs, rhs in
                let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if titleComparison != .orderedSame {
                    return titleComparison == .orderedAscending
                }
                return lhs.id < rhs.id
            }

        let timedItems = timedBlocks
            .map { block in
                DayPlanDayTaskListItem(
                    id: "timed-\(block.id.uuidString)",
                    taskID: block.taskID,
                    blockID: block.id,
                    title: block.titleSnapshot,
                    emoji: block.emojiSnapshot,
                    placement: .timed(
                        startMinute: block.startMinute,
                        durationMinutes: block.durationMinutes
                    )
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.placement, rhs.placement) {
                case let (.timed(lhsStart, _), .timed(rhsStart, _)) where lhsStart != rhsStart:
                    return lhsStart < rhsStart
                default:
                    let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                    if titleComparison != .orderedSame {
                        return titleComparison == .orderedAscending
                    }
                    return lhs.id < rhs.id
                }
            }

        return allDayItems + plannedDateItems + timedItems
    }

    private static func allDayBlockIntersects(
        _ block: DayPlanAllDayBlock,
        date: Date,
        calendar: Calendar
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return false
        }
        return block.startDate < dayEnd && block.endDate > dayStart
    }

    private static func isVisiblePlannedDateTask(
        _ task: RoutineTask,
        on date: Date,
        calendar: Calendar,
        visibilityCache: DayPlanPlannedDateTaskVisibilityCache?
    ) -> Bool {
        guard let plannedDate = task.plannedDate else { return false }
        let dayStart = calendar.startOfDay(for: date)
        let isDailyRoutineForTaskList = visibilityCache?.isDailyRoutineForTaskList(task)
            ?? task.isDailyRoutineForTaskList
        return !isDailyRoutineForTaskList
            && !task.isCompletedOneOff
            && !task.isCanceledOneOff
            && !task.isPinned
            && !task.isArchived(referenceDate: dayStart, calendar: calendar)
            && calendar.isDate(plannedDate, inSameDayAs: dayStart)
    }
}

final class DayPlanDayTaskListItemsCache: ObservableObject {
    private struct Signature: Hashable {
        var dataSnapshotID: UUID
        var dayKey: String
        var calendarIdentifier: String
        var timeZoneIdentifier: String
        var firstWeekday: Int
        var minimumDaysInFirstWeek: Int
        var visibilitySignature: DayPlanDayTaskListVisibilitySignature
        var timedBlocks: [TimedBlockSignature]

        init(
            dataSnapshotID: UUID,
            date: Date,
            timedBlocks: [DayPlanBlock],
            calendar: Calendar,
            visibilitySignature: DayPlanDayTaskListVisibilitySignature
        ) {
            self.dataSnapshotID = dataSnapshotID
            dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            calendarIdentifier = String(describing: calendar.identifier)
            timeZoneIdentifier = calendar.timeZone.identifier
            firstWeekday = calendar.firstWeekday
            minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
            self.visibilitySignature = visibilitySignature
            self.timedBlocks = timedBlocks.map(TimedBlockSignature.init(block:))
        }
    }

    private struct TimedBlockSignature: Hashable {
        var id: UUID
        var taskID: UUID
        var dayKey: String
        var startMinute: Int
        var durationMinutes: Int
        var titleSnapshot: String
        var emojiSnapshot: String?

        init(block: DayPlanBlock) {
            id = block.id
            taskID = block.taskID
            dayKey = block.dayKey
            startMinute = block.startMinute
            durationMinutes = block.durationMinutes
            titleSnapshot = block.titleSnapshot
            emojiSnapshot = block.emojiSnapshot
        }
    }

    private var itemsBySignature: [Signature: [DayPlanDayTaskListItem]] = [:]

    func items(
        dataSnapshotID: UUID,
        on date: Date,
        timedBlocks: [DayPlanBlock],
        allDayBlocks: [DayPlanAllDayBlock],
        plannedDateTasks: [RoutineTask],
        calendar: Calendar,
        visibilitySignature: DayPlanDayTaskListVisibilitySignature = .unfiltered,
        visibilityCache: DayPlanPlannedDateTaskVisibilityCache? = nil
    ) -> [DayPlanDayTaskListItem] {
        let signature = Signature(
            dataSnapshotID: dataSnapshotID,
            date: date,
            timedBlocks: timedBlocks,
            calendar: calendar,
            visibilitySignature: visibilitySignature
        )
        if let items = itemsBySignature[signature] {
            return items
        }

        let items = DayPlanDayTaskListPresentation.items(
            on: date,
            timedBlocks: timedBlocks,
            allDayBlocks: allDayBlocks,
            plannedDateTasks: plannedDateTasks,
            calendar: calendar,
            visibilityCache: visibilityCache
        )
        if itemsBySignature.count > 96 {
            itemsBySignature.removeAll(keepingCapacity: true)
        }
        itemsBySignature[signature] = items
        return items
    }
}

final class DayPlanPlannedDateTaskVisibilityCache: ObservableObject {
    private struct Signature: Equatable {
        var scheduleModeRawValue: String
        var recurrenceStorageVersion: Int16
        var recurrenceKindRawValue: String?
        var recurrenceTimeOfDayHour: Int?
        var recurrenceTimeOfDayMinute: Int?
        var recurrenceTimeRangeStartHour: Int?
        var recurrenceTimeRangeStartMinute: Int?
        var recurrenceTimeRangeEndHour: Int?
        var recurrenceTimeRangeEndMinute: Int?
        var recurrenceWeekday: Int?
        var recurrenceDayOfMonth: Int?
        var recurrenceRuleStorage: String
        var checklistItemsStorage: String

        init(task: RoutineTask) {
            scheduleModeRawValue = task.scheduleModeRawValue
            recurrenceStorageVersion = task.recurrenceStorageVersion
            recurrenceKindRawValue = task.recurrenceKindRawValue
            recurrenceTimeOfDayHour = task.recurrenceTimeOfDayHour
            recurrenceTimeOfDayMinute = task.recurrenceTimeOfDayMinute
            recurrenceTimeRangeStartHour = task.recurrenceTimeRangeStartHour
            recurrenceTimeRangeStartMinute = task.recurrenceTimeRangeStartMinute
            recurrenceTimeRangeEndHour = task.recurrenceTimeRangeEndHour
            recurrenceTimeRangeEndMinute = task.recurrenceTimeRangeEndMinute
            recurrenceWeekday = task.recurrenceWeekday
            recurrenceDayOfMonth = task.recurrenceDayOfMonth
            recurrenceRuleStorage = task.recurrenceRuleStorage
            checklistItemsStorage = task.checklistItemsStorage
        }
    }

    private struct Entry {
        var signature: Signature
        var isDailyRoutineForTaskList: Bool
    }

    private var entries: [UUID: Entry] = [:]

    func isDailyRoutineForTaskList(_ task: RoutineTask) -> Bool {
        let signature = Signature(task: task)
        if let entry = entries[task.id], entry.signature == signature {
            return entry.isDailyRoutineForTaskList
        }
        let value = task.isDailyRoutineForTaskList
        entries[task.id] = Entry(signature: signature, isDailyRoutineForTaskList: value)
        return value
    }
}

struct DayPlanTimedBlockColumnItem: Equatable {
    var id: String
    var startMinute: Int
    var endMinute: Int

    init(id: String, startMinute: Int, endMinute: Int) {
        let startMinute = min(max(startMinute, 0), DayPlanBlock.minutesPerDay - 1)
        self.id = id
        self.startMinute = startMinute
        self.endMinute = min(max(endMinute, startMinute + 1), DayPlanBlock.minutesPerDay)
    }
}

struct DayPlanTimedBlockColumnPlacement: Equatable {
    var id: String
    var columnIndex: Int
    var columnCount: Int
}

enum DayPlanTimedBlockColumnLayout {
    static func placements(
        for items: [DayPlanTimedBlockColumnItem]
    ) -> [DayPlanTimedBlockColumnPlacement] {
        guard !items.isEmpty else { return [] }

        let sortedItems = items.sorted { lhs, rhs in
            if lhs.startMinute != rhs.startMinute {
                return lhs.startMinute < rhs.startMinute
            }
            if lhs.endMinute != rhs.endMinute {
                return lhs.endMinute > rhs.endMinute
            }
            return lhs.id < rhs.id
        }

        var groupAssignments: [ColumnAssignment] = []
        var activeAssignments: [ColumnAssignment] = []
        var placementsByID: [String: DayPlanTimedBlockColumnPlacement] = [:]

        func flushGroup() {
            guard !groupAssignments.isEmpty else { return }

            let columnCount = (groupAssignments.map(\.columnIndex).max() ?? 0) + 1
            for assignment in groupAssignments {
                placementsByID[assignment.item.id] = DayPlanTimedBlockColumnPlacement(
                    id: assignment.item.id,
                    columnIndex: assignment.columnIndex,
                    columnCount: columnCount
                )
            }

            groupAssignments.removeAll(keepingCapacity: true)
        }

        for item in sortedItems {
            activeAssignments.removeAll { $0.item.endMinute <= item.startMinute }
            if activeAssignments.isEmpty {
                flushGroup()
            }

            let usedColumns = Set(activeAssignments.map(\.columnIndex))
            var columnIndex = 0
            while usedColumns.contains(columnIndex) {
                columnIndex += 1
            }

            let assignment = ColumnAssignment(item: item, columnIndex: columnIndex)
            groupAssignments.append(assignment)
            activeAssignments.append(assignment)
        }

        flushGroup()

        return items.compactMap { placementsByID[$0.id] }
    }
}

private struct ColumnAssignment {
    var item: DayPlanTimedBlockColumnItem
    var columnIndex: Int
}
