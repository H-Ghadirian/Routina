import Combine
import CoreGraphics
import Foundation

struct DayPlanAdaptiveTimeAxis: Equatable {
    static let minimumInteractiveBlockHeight: CGFloat = 18
    static let hourCount = 24
    static let minutesPerHour = 60

    struct Interval: Hashable {
        var groupID: String
        var startMinute: Int
        var durationMinutes: Int

        init(
            groupID: String = "default",
            startMinute: Int,
            durationMinutes: Int
        ) {
            self.groupID = groupID
            self.startMinute = min(max(startMinute, 0), DayPlanBlock.minutesPerDay)
            self.durationMinutes = min(
                max(durationMinutes, DayPlanBlock.minimumStoredDurationMinutes),
                max(DayPlanBlock.minutesPerDay - self.startMinute, 0)
            )
        }
    }

    let baseHourHeight: CGFloat
    let hourHeights: [CGFloat]
    private let hourOffsets: [CGFloat]

    init(baseHourHeight: CGFloat, intervals: [Interval] = []) {
        let sanitizedBaseHeight = max(baseHourHeight, 1)
        var resolvedHourHeights = Array(
            repeating: sanitizedBaseHeight,
            count: Self.hourCount
        )

        let intervalsByGroup = Dictionary(
            grouping: intervals.filter { $0.durationMinutes > 0 },
            by: \.groupID
        )

        for groupIntervals in intervalsByGroup.values {
            let sortedIntervals = groupIntervals.sorted {
                if $0.startMinute != $1.startMinute {
                    return $0.startMinute < $1.startMinute
                }
                return $0.durationMinutes < $1.durationMinutes
            }
            let sortedStartMinutes = sortedIntervals.map(\.startMinute)

            for interval in sortedIntervals {
                let intervalEndMinute = interval.startMinute + interval.durationMinutes
                guard
                    let nextStartMinute = Self.firstStartMinute(
                        atOrAfter: intervalEndMinute,
                        in: sortedStartMinutes
                    )
                else {
                    continue
                }

                let minuteGap = nextStartMinute - interval.startMinute
                guard minuteGap > 0 else { continue }

                let requiredHourHeight = max(
                    sanitizedBaseHeight,
                    Self.minimumInteractiveBlockHeight
                        * CGFloat(Self.minutesPerHour)
                        / CGFloat(minuteGap)
                )
                guard requiredHourHeight > sanitizedBaseHeight else { continue }

                let firstHour = min(
                    max(interval.startMinute / Self.minutesPerHour, 0),
                    Self.hourCount - 1
                )
                let lastMinute = max(nextStartMinute - 1, interval.startMinute)
                let lastHour = min(
                    max(lastMinute / Self.minutesPerHour, 0),
                    Self.hourCount - 1
                )

                for hour in firstHour...lastHour {
                    resolvedHourHeights[hour] = max(
                        resolvedHourHeights[hour],
                        requiredHourHeight
                    )
                }
            }
        }

        var offsets = Array(repeating: CGFloat.zero, count: Self.hourCount + 1)
        for hour in 0..<Self.hourCount {
            offsets[hour + 1] = offsets[hour] + resolvedHourHeights[hour]
        }

        self.baseHourHeight = sanitizedBaseHeight
        self.hourHeights = resolvedHourHeights
        self.hourOffsets = offsets
    }

    var contentHeight: CGFloat {
        hourOffsets.last ?? 0
    }

    var isAdaptive: Bool {
        hourHeights.contains { $0 > baseHourHeight + 0.5 }
    }

    func height(forHour hour: Int) -> CGFloat {
        hourHeights[min(max(hour, 0), Self.hourCount - 1)]
    }

    func yOffset(forMinute minute: Int) -> CGFloat {
        yOffset(forMinute: CGFloat(minute))
    }

    func yOffset(forMinute minute: CGFloat) -> CGFloat {
        let clampedMinute = min(max(minute, 0), CGFloat(DayPlanBlock.minutesPerDay))
        guard clampedMinute < CGFloat(DayPlanBlock.minutesPerDay) else {
            return contentHeight
        }

        let hour = min(
            max(Int(clampedMinute) / Self.minutesPerHour, 0),
            Self.hourCount - 1
        )
        let minuteWithinHour = clampedMinute - CGFloat(hour * Self.minutesPerHour)
        return hourOffsets[hour]
            + (minuteWithinHour / CGFloat(Self.minutesPerHour)) * hourHeights[hour]
    }

    func height(startMinute: Int, durationMinutes: Int) -> CGFloat {
        let start = min(max(startMinute, 0), DayPlanBlock.minutesPerDay)
        let end = min(
            max(start + durationMinutes, start),
            DayPlanBlock.minutesPerDay
        )
        return max(yOffset(forMinute: end) - yOffset(forMinute: start), 0)
    }

    func minute(atYOffset yOffset: CGFloat) -> CGFloat {
        let clampedY = min(max(yOffset, 0), contentHeight)
        guard clampedY < contentHeight else {
            return CGFloat(DayPlanBlock.minutesPerDay)
        }

        let hour = hourIndex(containingYOffset: clampedY)
        let hourStartY = hourOffsets[hour]
        let fraction = (clampedY - hourStartY) / max(hourHeights[hour], 1)
        return CGFloat(hour * Self.minutesPerHour)
            + (fraction * CGFloat(Self.minutesPerHour))
    }

    func snappedMinute(
        atYOffset yOffset: CGFloat,
        incrementMinutes: Int = 15
    ) -> Int {
        let increment = max(incrementMinutes, 1)
        let rawMinute = Int(minute(atYOffset: yOffset).rounded(.down))
        return min(
            max((rawMinute / increment) * increment, 0),
            DayPlanBlock.minutesPerDay - 1
        )
    }

    func minuteDelta(
        forVerticalDelta verticalDelta: CGFloat,
        fromMinute origin: Int,
        snappingTo incrementMinutes: Int? = nil
    ) -> Int {
        let originMinute = min(max(origin, 0), DayPlanBlock.minutesPerDay)
        let targetMinute = self.minute(
            atYOffset: yOffset(forMinute: originMinute) + verticalDelta
        )
        let resolvedTargetMinute: Int

        if let incrementMinutes {
            let increment = max(incrementMinutes, 1)
            resolvedTargetMinute =
                Int(
                    (targetMinute / CGFloat(increment)).rounded()
                ) * increment
        } else {
            resolvedTargetMinute = Int(targetMinute.rounded())
        }

        return min(max(resolvedTargetMinute, 0), DayPlanBlock.minutesPerDay)
            - originMinute
    }

    func nearestHour(toYOffset yOffset: CGFloat) -> Int {
        let minute = minute(atYOffset: yOffset)
        return min(
            max(Int((minute / CGFloat(Self.minutesPerHour)).rounded()), 0),
            Self.hourCount - 1
        )
    }

    private func hourIndex(containingYOffset yOffset: CGFloat) -> Int {
        var lowerBound = 0
        var upperBound = Self.hourCount

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            if hourOffsets[middle + 1] <= yOffset {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        return min(max(lowerBound, 0), Self.hourCount - 1)
    }

    private static func firstStartMinute(
        atOrAfter targetMinute: Int,
        in sortedStartMinutes: [Int]
    ) -> Int? {
        var lowerBound = 0
        var upperBound = sortedStartMinutes.count

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            if sortedStartMinutes[middle] < targetMinute {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        guard sortedStartMinutes.indices.contains(lowerBound) else { return nil }
        return sortedStartMinutes[lowerBound]
    }
}

final class DayPlanAdaptiveTimeAxisCache: ObservableObject {
    private struct Signature: Equatable {
        var baseHourHeight: CGFloat
        var intervals: [DayPlanAdaptiveTimeAxis.Interval]
    }

    private var cachedSignature: Signature?
    private(set) var currentAxis: DayPlanAdaptiveTimeAxis?

    func axis(
        baseHourHeight: CGFloat,
        intervals: [DayPlanAdaptiveTimeAxis.Interval]
    ) -> DayPlanAdaptiveTimeAxis {
        let signature = Signature(
            baseHourHeight: baseHourHeight,
            intervals: intervals
        )
        if cachedSignature == signature, let currentAxis {
            return currentAxis
        }

        let axis = DayPlanAdaptiveTimeAxis(
            baseHourHeight: baseHourHeight,
            intervals: signature.intervals
        )
        cachedSignature = signature
        currentAxis = axis
        return axis
    }
}

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

enum DayPlanVisibleBlocks {
    static func blocks(
        _ blocks: [DayPlanBlock],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar,
        referenceDate: Date = Date(),
        activeFocusSessions: [FocusSession] = [],
        activeFocusSegmentSearchBlocks: [DayPlanBlock]? = nil
    ) -> [DayPlanBlock] {
        Self.blocks(
            blocks,
            context: DayPlanVisibleBlockContext(
                tasks: tasks,
                logs: logs,
                calendar: calendar,
                referenceDate: referenceDate,
                activeFocusSessions: activeFocusSessions
            ),
            activeFocusSegmentSearchBlocks: activeFocusSegmentSearchBlocks
        )
    }

    static func blocks(
        _ blocks: [DayPlanBlock],
        context: DayPlanVisibleBlockContext,
        activeFocusSegmentSearchBlocks: [DayPlanBlock]? = nil
    ) -> [DayPlanBlock] {
        guard !blocks.isEmpty else { return [] }

        let correctedBlocks = context.correctedActiveFocusBlocks(blocks)
        let activeFocusSearchBlocks = context.correctedActiveFocusBlocks(
            activeFocusSegmentSearchBlocks ?? blocks
        )
        let activeCountUpSegmentBlockIDs = activeCountUpCurrentSegmentBlockIDs(
            activeFocusSearchBlocks,
            activeFocusSessions: context.activeFocusSessions,
            referenceDayKey: activeFocusSegmentSearchBlocks == nil ? nil : context.referenceDayKey
        )

        return correctedBlocks.filter { block in
            if activeCountUpSegmentBlockIDs.contains(block.id) {
                return false
            }

            guard context.tasksByID[block.taskID] != nil else { return true }
            guard !context.canceledOneOffTaskIDs.contains(block.taskID) else { return false }
            return !context.isHiddenTaskDay(taskID: block.taskID, dayKey: block.dayKey)
        }
    }

    private static func activeCountUpCurrentSegmentBlockIDs(
        _ blocks: [DayPlanBlock],
        activeFocusSessions: [FocusSession],
        referenceDayKey: String?
    ) -> Set<UUID> {
        Set(
            activeFocusSessions.compactMap { session in
                guard session.plannedDurationSeconds <= 0,
                    session.completedAt == nil,
                    session.abandonedAt == nil,
                    session.pausedAt == nil,
                    session.startedAt != nil,
                    session.isTaskFocus || session.isTagFocus
                else {
                    return nil
                }

                guard
                    let latestSegmentBlock = DayPlanFocusSessionPlannerSync.latestFocusSegmentBlock(
                        in: blocks,
                        for: session
                    )
                else {
                    return nil
                }

                if let referenceDayKey, latestSegmentBlock.dayKey != referenceDayKey {
                    return nil
                }

                if latestSegmentBlock.id == session.id, session.accumulatedPausedSeconds > 0 {
                    return nil
                }

                return latestSegmentBlock.id
            })
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
