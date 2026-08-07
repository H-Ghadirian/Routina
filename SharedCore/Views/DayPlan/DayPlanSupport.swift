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
                guard let nextStartMinute = Self.firstStartMinute(
                    atOrAfter: intervalEndMinute,
                    in: sortedStartMinutes
                ) else {
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
            resolvedTargetMinute = Int(
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
              let day = Self.date(fromDayKey: dayKey, calendar: calendar) else {
            return false
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
              let day = Int(parts[2]) else {
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
                  !block.isEvent else {
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
        guard filters.includesTimelineActivity(
            activity,
            includesAssumedDone: includesAssumedDone
        ) else {
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
        Set(activeFocusSessions.compactMap { session in
            guard session.plannedDurationSeconds <= 0,
                  session.completedAt == nil,
                  session.abandonedAt == nil,
                  session.pausedAt == nil,
                  session.startedAt != nil,
                  session.isTaskFocus || session.isTagFocus else {
                return nil
            }

            guard let latestSegmentBlock = DayPlanFocusSessionPlannerSync.latestFocusSegmentBlock(
                in: blocks,
                for: session
            ) else {
                return nil
            }

            if let referenceDayKey, latestSegmentBlock.dayKey != referenceDayKey {
                return nil
            }

            if latestSegmentBlock.id == session.id,
               session.accumulatedPausedSeconds > 0 {
                return nil
            }

            return latestSegmentBlock.id
        })
    }
}

struct DayPlanDoneTaskOccurrence: Equatable {
    var source: DayPlanTimelineActivitySource
    var completedAt: Date
    var durationMinutes: Int
    var hasSpecificTime: Bool = true
}

struct DayPlanDayTaskListItem: Identifiable, Equatable {
    enum Section: String, CaseIterable, Equatable {
        case planned
        case assumedDone
        case done

        var title: String {
            switch self {
            case .planned:
                return "Planned tasks"
            case .assumedDone:
                return "Assumed done"
            case .done:
                return "Dones"
            }
        }
    }

    enum Placement: Equatable {
        case anyTime
        case allDay
        case durationOnly(durationMinutes: Int)
        case timed(startMinute: Int, durationMinutes: Int)
    }

    var id: String
    var taskID: UUID
    var blockID: UUID?
    var title: String
    var emoji: String?
    var section: Section = .planned
    var placement: Placement
    var doneOccurrence: DayPlanDoneTaskOccurrence? = nil
    var plannedCompletionDate: Date? = nil
}

struct DayPlanDayTaskCounts: Equatable {
    var planned: Int = 0
    var assumedDone: Int = 0
    var done: Int = 0

    var total: Int {
        planned + assumedDone + done
    }

    init(planned: Int = 0, assumedDone: Int = 0, done: Int = 0) {
        self.planned = planned
        self.assumedDone = assumedDone
        self.done = done
    }

    init(items: [DayPlanDayTaskListItem]) {
        for item in items {
            switch item.section {
            case .planned:
                planned += 1
            case .assumedDone:
                assumedDone += 1
            case .done:
                done += 1
            }
        }
    }
}

struct DayPlanDayTaskResolutionOverlay: Equatable {
    enum Resolution: Equatable {
        case completed(DayPlanDoneTaskOccurrence)
        case missed
    }

    private struct Key: Hashable {
        var taskID: UUID
        var dayKey: String
    }

    private var resolutions: [Key: Resolution] = [:]

    mutating func complete(
        _ item: DayPlanDayTaskListItem,
        on date: Date,
        completedAt: Date,
        calendar: Calendar
    ) {
        resolutions[key(for: item.taskID, on: date, calendar: calendar)] = .completed(
            DayPlanDoneTaskOccurrence(
                source: .taskLastDone,
                completedAt: completedAt,
                durationMinutes: durationMinutes(for: item.placement),
                hasSpecificTime: hasSpecificTime(for: item.placement)
            )
        )
    }

    mutating func markMissed(
        taskID: UUID,
        on date: Date,
        calendar: Calendar
    ) {
        resolutions[key(for: taskID, on: date, calendar: calendar)] = .missed
    }

    mutating func reset() {
        resolutions.removeAll(keepingCapacity: true)
    }

    func applying(
        to items: [DayPlanDayTaskListItem],
        on date: Date,
        calendar: Calendar
    ) -> [DayPlanDayTaskListItem] {
        guard !resolutions.isEmpty else { return items }
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)

        return items.compactMap { item in
            guard let resolution = resolutions[Key(taskID: item.taskID, dayKey: dayKey)]
            else {
                return item
            }

            switch resolution {
            case let .completed(doneOccurrence):
                guard item.section == .planned || item.section == .assumedDone else {
                    return item
                }
                var confirmedItem = item
                confirmedItem.section = .done
                confirmedItem.doneOccurrence = doneOccurrence
                confirmedItem.plannedCompletionDate = nil
                return confirmedItem
            case .missed:
                return item.section == .assumedDone ? nil : item
            }
        }
    }

    private func key(
        for taskID: UUID,
        on date: Date,
        calendar: Calendar
    ) -> Key {
        Key(
            taskID: taskID,
            dayKey: DayPlanStorage.dayKey(for: date, calendar: calendar)
        )
    }

    private func durationMinutes(for placement: DayPlanDayTaskListItem.Placement) -> Int {
        switch placement {
        case let .durationOnly(durationMinutes), let .timed(_, durationMinutes):
            return durationMinutes
        case .anyTime, .allDay:
            return 0
        }
    }

    private func hasSpecificTime(for placement: DayPlanDayTaskListItem.Placement) -> Bool {
        if case .timed = placement {
            return true
        }
        return false
    }
}

enum DayPlanPlannedTaskCompletion {
    static func completionDate(
        for task: RoutineTask,
        on selectedDay: Date,
        placement: DayPlanDayTaskListItem.Placement,
        referenceDate: Date,
        logs: [RoutineLog],
        calendar: Calendar
    ) -> Date? {
        let selectedDayStart = calendar.startOfDay(for: selectedDay)
        let referenceDayStart = calendar.startOfDay(for: referenceDate)
        guard selectedDayStart <= referenceDayStart,
              !task.hasSequentialSteps,
              !task.isChecklistCompletionRoutine,
              !task.blocksManualCompletionForIncompleteChecklist
        else {
            return nil
        }

        if RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) {
            guard let completionDate = RoutineDateMath.completionTargetDate(
                for: task,
                selectedDay: selectedDayStart,
                referenceDate: referenceDate,
                calendar: calendar
            ), RoutineDateMath.canMarkSelectedExactTimedOccurrenceDone(
                for: task,
                completionDate: completionDate,
                referenceDate: referenceDate,
                logs: logs,
                calendar: calendar
            ) else {
                return nil
            }
            return completionDate
        }

        let completionDate: Date
        if calendar.isDate(selectedDayStart, inSameDayAs: referenceDayStart) {
            completionDate = referenceDate
        } else if case let .timed(startMinute, durationMinutes) = placement {
            completionDate = calendar.date(
                byAdding: .minute,
                value: startMinute + durationMinutes,
                to: selectedDayStart
            ) ?? selectedDayStart
        } else if let timeOfDay = task.recurrenceRule.timeRange?.start
            ?? task.recurrenceRule.timeOfDay,
            !task.isOneOffTask {
            completionDate = timeOfDay.date(on: selectedDayStart, calendar: calendar)
        } else {
            completionDate = calendar.date(
                bySettingHour: 12,
                minute: 0,
                second: 0,
                of: selectedDayStart
            ) ?? selectedDayStart
        }

        let isHistoricalCompletion = !calendar.isDate(
            completionDate,
            inSameDayAs: referenceDate
        )
        let canMarkDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: completionDate,
            calendar: calendar,
            ignoreArchiveAtReferenceDate: isHistoricalCompletion
        )
        let canCompleteEarly = RoutineDateMath.canCompleteScheduledOccurrenceEarly(
            for: task,
            completedAt: completionDate,
            calendar: calendar
        )
        return canMarkDone || canCompleteEarly ? completionDate : nil
    }
}

enum DayPlanDayTaskListPresentation {
    static func items(
        on date: Date,
        timedBlocks: [DayPlanBlock],
        allDayBlocks: [DayPlanAllDayBlock],
        plannedDateTasks: [RoutineTask] = [],
        timelineActivityBlocks: [DayPlanTimelineActivityBlock] = [],
        tasks: [RoutineTask] = [],
        logs: [RoutineLog] = [],
        referenceDate: Date = Date(),
        calendar: Calendar,
        visibilityCache: DayPlanPlannedDateTaskVisibilityCache? = nil
    ) -> [DayPlanDayTaskListItem] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        let completionContext = DayPlanDayTaskListCompletionContext(
            tasks: tasks,
            logs: logs,
            calendar: calendar
        )
        let allDayItems = allDayBlocks
            .enumerated()
            .compactMap { offset, allDayBlock -> DayPlanDayTaskListItem? in
                guard let taskID = allDayBlock.taskID,
                      !allDayBlock.isEvent,
                      allDayBlockIntersects(allDayBlock, date: date, calendar: calendar) else {
                    return nil
                }
                guard let section = completionContext.sectionForPlannerBackedTask(
                    taskID,
                    dayKey: dayKey
                ) else {
                    return nil
                }

                return DayPlanDayTaskListItem(
                    id: "all-day-\(taskID.uuidString)-\(offset)",
                    taskID: taskID,
                    blockID: nil,
                    title: allDayBlock.title,
                    emoji: allDayBlock.emoji,
                    section: section,
                    placement: .allDay,
                    doneOccurrence: section == .done
                        ? completionContext.doneOccurrence(taskID, dayKey: dayKey)
                        : nil
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
                      !completionContext.hasCompletion(
                        task.id,
                        dayKey: dayKey
                      ),
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
                    placement: .anyTime
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
            .compactMap { block -> DayPlanDayTaskListItem? in
                let section: DayPlanDayTaskListItem.Section
                if block.taskID == FocusSession.unassignedTaskID {
                    section = .done
                } else {
                    guard let plannerSection = completionContext.sectionForPlannerBackedTask(
                        block.taskID,
                        dayKey: dayKey
                    ) else {
                        return nil
                    }
                    section = plannerSection
                }

                return DayPlanDayTaskListItem(
                    id: "timed-\(block.id.uuidString)",
                    taskID: block.taskID,
                    blockID: block.id,
                    title: block.titleSnapshot,
                    emoji: block.emojiSnapshot,
                    section: section,
                    placement: .timed(
                        startMinute: block.startMinute,
                        durationMinutes: block.durationMinutes
                    ),
                    doneOccurrence: section == .done
                        ? completionContext.doneOccurrence(block.taskID, dayKey: dayKey)
                        : nil
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

        let activityItems = timelineActivityBlocks
            .compactMap { activity -> DayPlanDayTaskListItem? in
                guard activity.kind == .completed else { return nil }

                let block = activity.block
                return DayPlanDayTaskListItem(
                    id: "\(activity.source.isSyntheticAssumedDone ? "assumed" : "done")-\(activity.id)",
                    taskID: block.taskID,
                    blockID: nil,
                    title: block.titleSnapshot,
                    emoji: block.emojiSnapshot,
                    section: activity.source.isSyntheticAssumedDone ? .assumedDone : .done,
                    placement: activity.hasSpecificTime
                        ? .timed(
                            startMinute: block.startMinute,
                            durationMinutes: block.durationMinutes
                        )
                        : .durationOnly(durationMinutes: block.durationMinutes),
                    doneOccurrence: activity.source.isSyntheticAssumedDone
                        ? nil
                        : DayPlanDoneTaskOccurrence(
                            source: activity.source,
                            completedAt: block.updatedAt,
                            durationMinutes: block.durationMinutes,
                            hasSpecificTime: activity.hasSpecificTime
                        )
                )
            }

        let assumedDoneItems = sortedActivityItems(
            activityItems.filter { $0.section == .assumedDone }
        )
        let assumedDoneTaskIDs = Set(assumedDoneItems.map(\.taskID))
        let rawDoneItems = sortedActivityItems(
            allDayItems.filter { $0.section == .done }
                + timedItems.filter { $0.section == .done }
                + activityItems.filter { $0.section == .done }
        )
        let plannedAllDayItems = allDayItems.filter { $0.section == .planned && !assumedDoneTaskIDs.contains($0.taskID) }
        let plannedTimedItems = timedItems.filter { $0.section == .planned && !assumedDoneTaskIDs.contains($0.taskID) }
        let visibleTaskIDsBeforeFulfillmentSuppression = Set(
            (plannedAllDayItems + plannedDateItems + plannedTimedItems + assumedDoneItems + rawDoneItems)
                .map(\.taskID)
        )
        let doneItems = rawDoneItems.filter { item in
            let sourceTaskIDs = completionContext.fulfillmentSourceTaskIDs(
                for: item.taskID,
                dayKey: dayKey
            )
            guard !sourceTaskIDs.isEmpty,
                  !completionContext.hasDirectCompletion(item.taskID, dayKey: dayKey),
                  !sourceTaskIDs.isDisjoint(with: visibleTaskIDsBeforeFulfillmentSuppression)
            else {
                return true
            }
            return false
        }

        return (plannedAllDayItems
            + plannedDateItems
            + plannedTimedItems
            + assumedDoneItems
            + doneItems)
            .map { item in
                guard item.section == .planned,
                      let task = completionContext.task(item.taskID)
                else {
                    return item
                }
                var completableItem = item
                completableItem.plannedCompletionDate = DayPlanPlannedTaskCompletion.completionDate(
                    for: task,
                    on: date,
                    placement: item.placement,
                    referenceDate: referenceDate,
                    logs: logs,
                    calendar: calendar
                )
                return completableItem
            }
    }

    private static func sortedActivityItems(_ items: [DayPlanDayTaskListItem]) -> [DayPlanDayTaskListItem] {
        items.sorted { lhs, rhs in
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
        return RoutineTaskPlanningSupport.supportsStoredPlanning(
                scheduleMode: task.scheduleMode,
                trackingCadenceEnabled: task.trackingCadenceEnabled,
                isDailyRoutine: isDailyRoutineForTaskList
            )
            && !task.isCompletedOneOff
            && !task.isCanceledOneOff
            && !task.isPinned
            && !task.isArchived(referenceDate: dayStart, calendar: calendar)
            && calendar.isDate(plannedDate, inSameDayAs: dayStart)
    }
}

private struct DayPlanDayTaskListCompletionContext {
    private var tasksByID: [UUID: RoutineTask] = [:]
    private var completedDayKeysByTaskID: [UUID: Set<String>] = [:]
    private var directCompletedDayKeysByTaskID: [UUID: Set<String>] = [:]
    private var fulfillmentSourceTaskIDsByTaskIDAndDayKey: [UUID: [String: Set<UUID>]] = [:]
    private var doneOccurrencesByTaskIDAndDayKey: [UUID: [String: DayPlanDoneTaskOccurrence]] = [:]

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar
    ) {
        for task in tasks {
            tasksByID[task.id] = task
            if let lastDone = task.lastDone,
               let dayKey = recordCompletion(lastDone, taskID: task.id, calendar: calendar) {
                recordDoneOccurrence(
                    DayPlanDoneTaskOccurrence(
                        source: .taskLastDone,
                        completedAt: lastDone,
                        durationMinutes: effectiveDurationMinutes(
                            actualDurationMinutes: task.actualDurationMinutes,
                            task: task
                        ),
                        hasSpecificTime: true
                    ),
                    taskID: task.id,
                    dayKey: dayKey
                )
            }
        }

        for log in logs where log.kind.resolvesDoneDate {
            guard let dayKey = recordCompletion(log.timestamp, taskID: log.taskID, calendar: calendar) else {
                continue
            }
            switch log.kind {
            case .completed:
                directCompletedDayKeysByTaskID[log.taskID, default: []].insert(dayKey)
                if let timestamp = log.timestamp {
                    recordDoneOccurrence(
                        DayPlanDoneTaskOccurrence(
                            source: .log(log.id),
                            completedAt: timestamp,
                            durationMinutes: effectiveDurationMinutes(
                                actualDurationMinutes: log.actualDurationMinutes,
                                task: tasksByID[log.taskID]
                            ),
                            hasSpecificTime: log.hasSpecificWorkTime ?? true
                        ),
                        taskID: log.taskID,
                        dayKey: dayKey
                    )
                }
            case .fulfilled:
                guard let sourceTaskID = log.sourceTaskID else { break }
                fulfillmentSourceTaskIDsByTaskIDAndDayKey[log.taskID, default: [:]][dayKey, default: []]
                    .insert(sourceTaskID)
            case .canceled, .missed:
                break
            }
        }
    }

    @discardableResult
    mutating private func recordCompletion(
        _ timestamp: Date?,
        taskID: UUID,
        calendar: Calendar
    ) -> String? {
        guard let timestamp else { return nil }
        let dayKey = displayDayKey(for: timestamp, taskID: taskID, calendar: calendar)
        completedDayKeysByTaskID[taskID, default: []].insert(dayKey)
        return dayKey
    }

    private func displayDayKey(
        for timestamp: Date,
        taskID: UUID,
        calendar: Calendar
    ) -> String {
        let displayDay = tasksByID[taskID]
            .flatMap { task in
                RoutineDateMath.completionDisplayDay(
                    for: task,
                    completionDate: timestamp,
                    calendar: calendar
                )
            }
            ?? calendar.startOfDay(for: timestamp)
        return DayPlanStorage.dayKey(for: displayDay, calendar: calendar)
    }

    func hasCompletion(
        _ taskID: UUID,
        dayKey: String
    ) -> Bool {
        completedDayKeysByTaskID[taskID]?.contains(dayKey) == true
    }

    func hasDirectCompletion(
        _ taskID: UUID,
        dayKey: String
    ) -> Bool {
        directCompletedDayKeysByTaskID[taskID]?.contains(dayKey) == true
    }

    func fulfillmentSourceTaskIDs(
        for taskID: UUID,
        dayKey: String
    ) -> Set<UUID> {
        fulfillmentSourceTaskIDsByTaskIDAndDayKey[taskID]?[dayKey] ?? []
    }

    func doneOccurrence(
        _ taskID: UUID,
        dayKey: String
    ) -> DayPlanDoneTaskOccurrence? {
        doneOccurrencesByTaskIDAndDayKey[taskID]?[dayKey]
    }

    func task(_ taskID: UUID) -> RoutineTask? {
        tasksByID[taskID]
    }

    func sectionForPlannerBackedTask(
        _ taskID: UUID,
        dayKey: String
    ) -> DayPlanDayTaskListItem.Section? {
        if hasCompletion(taskID, dayKey: dayKey) {
            return .done
        }
        if tasksByID[taskID]?.isCompletedOneOff == true {
            return nil
        }
        return .planned
    }

    private mutating func recordDoneOccurrence(
        _ occurrence: DayPlanDoneTaskOccurrence,
        taskID: UUID,
        dayKey: String
    ) {
        if let current = doneOccurrencesByTaskIDAndDayKey[taskID]?[dayKey],
           occurrence.completedAt < current.completedAt {
            return
        }
        doneOccurrencesByTaskIDAndDayKey[taskID, default: [:]][dayKey] = occurrence
    }

    private func effectiveDurationMinutes(
        actualDurationMinutes: Int?,
        task: RoutineTask?
    ) -> Int {
        actualDurationMinutes
            ?? task?.estimatedDurationMinutes
            ?? DayPlanBlock.minimumDurationMinutes * 2
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
        var completionReferenceMinute: Int
        var timedBlocks: [TimedBlockSignature]
        var timelineActivities: [TimelineActivitySignature]

        init(
            dataSnapshotID: UUID,
            date: Date,
            timedBlocks: [DayPlanBlock],
            timelineActivityBlocks: [DayPlanTimelineActivityBlock],
            referenceDate: Date,
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
            completionReferenceMinute = Int(referenceDate.timeIntervalSinceReferenceDate / 60)
            self.timedBlocks = timedBlocks.map(TimedBlockSignature.init(block:))
            timelineActivities = timelineActivityBlocks
                .map(TimelineActivitySignature.init(activity:))
                .sorted { $0.id < $1.id }
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

    private struct TimelineActivitySignature: Hashable {
        var id: String
        var kindRawValue: String
        var taskID: UUID
        var dayKey: String
        var startMinute: Int
        var durationMinutes: Int
        var titleSnapshot: String
        var emojiSnapshot: String?
        var updatedAt: Date

        init(activity: DayPlanTimelineActivityBlock) {
            let block = activity.block
            id = activity.id
            kindRawValue = activity.kind.rawValue
            taskID = block.taskID
            dayKey = block.dayKey
            startMinute = block.startMinute
            durationMinutes = block.durationMinutes
            titleSnapshot = block.titleSnapshot
            emojiSnapshot = block.emojiSnapshot
            updatedAt = block.updatedAt
        }
    }

    private var itemsBySignature: [Signature: [DayPlanDayTaskListItem]] = [:]

    func items(
        dataSnapshotID: UUID,
        on date: Date,
        timedBlocks: [DayPlanBlock],
        allDayBlocks: [DayPlanAllDayBlock],
        plannedDateTasks: [RoutineTask],
        timelineActivityBlocks: [DayPlanTimelineActivityBlock] = [],
        tasks: [RoutineTask] = [],
        logs: [RoutineLog] = [],
        referenceDate: Date = Date(),
        calendar: Calendar,
        visibilitySignature: DayPlanDayTaskListVisibilitySignature = .unfiltered,
        visibilityCache: DayPlanPlannedDateTaskVisibilityCache? = nil
    ) -> [DayPlanDayTaskListItem] {
        let signature = Signature(
            dataSnapshotID: dataSnapshotID,
            date: date,
            timedBlocks: timedBlocks,
            timelineActivityBlocks: timelineActivityBlocks,
            referenceDate: referenceDate,
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
            timelineActivityBlocks: timelineActivityBlocks,
            tasks: tasks,
            logs: logs,
            referenceDate: referenceDate,
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
