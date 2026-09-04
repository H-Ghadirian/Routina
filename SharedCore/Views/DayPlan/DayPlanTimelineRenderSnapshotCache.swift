import SwiftData
import SwiftUI

@MainActor
final class DayPlanTimelineRenderSnapshotCache: ObservableObject {
    private var cachedKey: DayPlanTimelineRenderSnapshotKey?
    private var cachedSnapshot: DayPlanTimelineRenderSnapshot?

    func snapshot(
        dataSnapshotID: UUID,
        planner: DayPlanPlannerState,
        tasks: [RoutineTask],
        logs: [RoutineLog],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        events: [RoutineEvent],
        includesEvents: Bool,
        sprintFocusSessions: [SprintFocusSessionRecord],
        sprintFocusAllocations: [SprintFocusAllocationRecord],
        boardSprints: [BoardSprintRecord],
        focusSessions: [FocusSession],
        referenceDate: Date,
        calendar: Calendar,
        modelContext: ModelContext,
        showsTimelineTasksInDayPlanner: Bool,
        hiddenTimelineActivityStorage: String,
        timelinePlacementCache: DayPlanTimelinePlacementCache,
        allDayBlocksCache: DayPlanAllDayBlocksCache,
        visibleBlockContextCache: DayPlanVisibleBlockContextCache,
        sleepBlocksCache: DayPlanSleepBlocksCache,
        awayBlocksCache: DayPlanAwayBlocksCache,
        completedSprintFocusBlocksCache: DayPlanSprintFocusBlocksCache,
        activeSprintFocusBlocksCache: DayPlanSprintFocusBlocksCache
    ) -> DayPlanTimelineRenderSnapshot {
        let visibleDates = planner.visibleDates(calendar: calendar)
        let refreshesEveryMinute =
            Self.hasVisibleOpenEndedTimelineBlock(
                visibleDates: visibleDates,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                sprintFocusSessions: sprintFocusSessions,
                referenceDate: referenceDate,
                calendar: calendar
            ) || tasks.contains { RoutineAssumedCompletion.isEligible($0) }
        let visibleEvents = includesEvents ? events : []
        let key = DayPlanTimelineRenderSnapshotKey(
            dataSnapshotID: dataSnapshotID,
            visibleDates: visibleDates,
            selectedDate: planner.selectedDate,
            focusedUnplannedCompletedDate: planner.focusedUnplannedCompletedDate,
            plannerBlocks: planner.blocks,
            plannerWeekBlocksByDayKey: planner.weekBlocksByDayKey,
            referenceDate: referenceDate,
            refreshesEveryMinute: refreshesEveryMinute,
            calendar: calendar,
            includesEvents: includesEvents,
            showsTimelineTasksInDayPlanner: showsTimelineTasksInDayPlanner,
            hiddenTimelineActivityStorage: hiddenTimelineActivityStorage
        )

        if cachedKey == key, let cachedSnapshot {
            return cachedSnapshot
        }

        let activeTaskAndTagFocusSessions = activeTaskAndTagFocusSessions(from: focusSessions)
        let visibleBlockContext = visibleBlockContextCache.context(
            tasks: tasks,
            logs: logs,
            calendar: calendar,
            referenceDate: referenceDate,
            activeFocusSessions: activeTaskAndTagFocusSessions
        )
        let plannedBlockPresentation = plannedBlockPresentation(
            for: visibleDates,
            planner: planner,
            visibleBlockContext: visibleBlockContext,
            calendar: calendar,
            context: modelContext
        )
        let plannedBlocksByDayKey = plannedBlockPresentation.visibleBlocksByDayKey
        let rawPlannedBlocks = plannedBlockPresentation.rawBlocks
        let hiddenTimelineActivityIDs = DayPlanHiddenTimelineActivityStore.hiddenIDs(from: hiddenTimelineActivityStorage)
        let sleepBlocksByDayKey = sleepBlocksCache.blocksByDayKey(
            on: visibleDates,
            from: sleepSessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let awayBlocksByDayKey = awayBlocksCache.blocksByDayKey(
            on: visibleDates,
            from: awaySessions,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let completedSprintFocusSessions = sprintFocusSessions.filter { !$0.isActive }
        let activeSprintFocusSessions = sprintFocusSessions.filter(\.isActive)
        let sprintFocusBlocksByDayKey = completedSprintFocusBlocksCache.blocksByDayKey(
            on: visibleDates,
            from: completedSprintFocusSessions,
            allocations: sprintFocusAllocations,
            sprints: boardSprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let activeSprintFocusBlocksByDayKey = activeSprintFocusBlocksCache.blocksByDayKey(
            on: visibleDates,
            from: activeSprintFocusSessions,
            allocations: sprintFocusAllocations,
            sprints: boardSprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let eventBlocksByDayKey = DayPlanEventBlocks.blocksByDayKey(
            on: visibleDates,
            from: visibleEvents,
            calendar: calendar
        )
        let automaticOccupiedBlocksByDayKey = mergePlannerBlocks(
            plannedBlocksByDayKey,
            eventBlocksByDayKey.mapValues { $0.map(\.block) }
        )
        let blockedIntervalsByDayKey = mergeBlockedIntervals(
            mergeBlockedIntervals(
                sleepBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) },
                awayBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) }
            ),
            mergeBlockedIntervals(
                sprintFocusBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) },
                activeSprintFocusBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) }
            )
        )
        let rawAutomaticSuggestionPlacementsByDayKey = timelinePlacementCache.automaticSuggestionPlacementsByDayKey(
            on: visibleDates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: automaticOccupiedBlocksByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenTimelineActivityIDs,
            referenceDate: referenceDate
        )
        let rawAutomaticSuggestionBlocksByDayKey = rawAutomaticSuggestionPlacementsByDayKey.mapValues(\.placed)
        let assumedDoneSummaryBlocksByDayKey = DayPlanTimelineTasks.assumedDoneSummaryBlocksByDayKey(
            on: visibleDates,
            from: tasks,
            logs: logs,
            calendar: calendar,
            hiddenActivityIDs: hiddenTimelineActivityIDs,
            referenceDate: referenceDate
        )
        let linkedAwayBlocksByDayKey = DayPlanAwayBlocks.linkedBlocksByDayKey(
            awayBlocksByDayKey,
            timelineActivitiesByDayKey: rawAutomaticSuggestionBlocksByDayKey
        )
        let timelineBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]] =
            showsTimelineTasksInDayPlanner
            ? [:]
            : DayPlanTimelineTasks.activityBlocksByDayKey(
                on: visibleDates,
                from: tasks,
                logs: logs,
                plannedBlocksByDayKey: automaticOccupiedBlocksByDayKey,
                blockedIntervalsByDayKey: blockedIntervalsByDayKey,
                calendar: calendar,
                hiddenActivityIDs: hiddenTimelineActivityIDs,
                referenceDate: referenceDate
            )
        let visibleAutomaticSuggestionPlacementsByDayKey: [String: DayPlanTimelineActivityPlacement] =
            showsTimelineTasksInDayPlanner
            ? Dictionary(
                uniqueKeysWithValues: rawAutomaticSuggestionPlacementsByDayKey.map { dayKey, placement in
                    (
                        dayKey,
                        placement.filteringBlockedIntervals(blockedIntervalsByDayKey[dayKey] ?? [])
                    )
                }
            )
            : [:]
        let allDayBlocks = allDayBlocksCache.blocks(
            on: visibleDates,
            from: tasks,
            logs: logs,
            events: visibleEvents,
            calendar: calendar
        )
        let selectedDayKey = DayPlanStorage.dayKey(for: planner.selectedDate, calendar: calendar)
        let selectedDayBlockedMinutes = blockedIntervalsByDayKey[selectedDayKey, default: []]
            .reduce(0) { $0 + $1.durationMinutes }
        let activeFocusRenderSessions = activeFocusSessions(from: focusSessions)
        let snapshot = DayPlanTimelineRenderSnapshot(
            visibleDates: visibleDates,
            tasks: tasks,
            logs: logs,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            events: visibleEvents,
            sprintFocusSessions: sprintFocusSessions,
            sprintFocusAllocations: sprintFocusAllocations,
            boardSprints: boardSprints,
            focusSessions: focusSessions,
            activeSprintFocusSessions: activeSprintFocusSessions,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            rawPlannedBlocks: rawPlannedBlocks,
            sleepBlocksByDayKey: sleepBlocksByDayKey,
            linkedAwayBlocksByDayKey: linkedAwayBlocksByDayKey,
            sprintFocusBlocksByDayKey: sprintFocusBlocksByDayKey,
            eventBlocksByDayKey: eventBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            timelineBlocksByDayKey: timelineBlocksByDayKey,
            unplaceableAutomaticSuggestionBlocksByDayKey: visibleAutomaticSuggestionPlacementsByDayKey.mapValues(\.unplaced),
            automaticSuggestionBlocksByDayKey: visibleAutomaticSuggestionPlacementsByDayKey.mapValues(\.placed),
            assumedDoneSummaryBlocksByDayKey: assumedDoneSummaryBlocksByDayKey,
            allDayBlocks: allDayBlocks,
            visibleBlockContext: visibleBlockContext,
            selectedDayBlockedMinutes: selectedDayBlockedMinutes,
            tintsByTaskID: tintsByTaskID(from: tasks),
            activeFocusRenderSessions: activeFocusRenderSessions,
            planFocusAllocatedMinutesBySessionID: DayPlanFocusSessionPlannerSync.planFocusAllocatedMinutesBySessionID(
                for: activeFocusRenderSessions.filter(\.isUnassigned),
                context: modelContext
            )
        )
        cachedKey = key
        cachedSnapshot = snapshot
        return snapshot
    }

    private func plannedBlockPresentation(
        for dates: [Date],
        planner: DayPlanPlannerState,
        visibleBlockContext: DayPlanVisibleBlockContext,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanPlannedBlockPresentation {
        var visibleBlocksByDayKey: [String: [DayPlanBlock]] = [:]
        var rawBlocksByDayKey: [String: [DayPlanBlock]] = [:]
        var rawBlocks: [DayPlanBlock] = []
        visibleBlocksByDayKey.reserveCapacity(dates.count)
        rawBlocksByDayKey.reserveCapacity(dates.count)

        for date in dates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            let blocks = planner.blocks(on: date, calendar: calendar, context: context)
            rawBlocksByDayKey[dayKey] = blocks
            rawBlocks.append(contentsOf: blocks)
        }

        for date in dates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            let blocks = rawBlocksByDayKey[dayKey] ?? []
            visibleBlocksByDayKey[dayKey] = DayPlanVisibleBlocks.blocks(
                blocks,
                context: visibleBlockContext,
                activeFocusSegmentSearchBlocks: rawBlocks
            )
        }

        return DayPlanPlannedBlockPresentation(
            visibleBlocksByDayKey: visibleBlocksByDayKey,
            rawBlocks: rawBlocks
        )
    }

    private func activeTaskAndTagFocusSessions(from sessions: [FocusSession]) -> [FocusSession] {
        sessions.filter { session in
            (session.isTaskFocus || session.isTagFocus)
                && session.startedAt != nil
                && session.completedAt == nil
                && session.abandonedAt == nil
        }
    }

    private func activeFocusSessions(from sessions: [FocusSession]) -> [FocusSession] {
        sessions
            .filter { $0.startedAt != nil }
            .filter { $0.completedAt == nil && $0.abandonedAt == nil }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    private func mergeBlockedIntervals(
        _ lhs: [String: [DayPlanBlockedInterval]],
        _ rhs: [String: [DayPlanBlockedInterval]]
    ) -> [String: [DayPlanBlockedInterval]] {
        var result = lhs
        for (dayKey, intervals) in rhs {
            result[dayKey, default: []].append(contentsOf: intervals)
        }
        return result
    }

    private func mergePlannerBlocks(
        _ lhs: [String: [DayPlanBlock]],
        _ rhs: [String: [DayPlanBlock]]
    ) -> [String: [DayPlanBlock]] {
        var result = lhs
        for (dayKey, blocks) in rhs {
            result[dayKey, default: []].append(contentsOf: blocks)
        }
        return result
    }

    private func tintsByTaskID(from tasks: [RoutineTask]) -> [UUID: Color] {
        var result: [UUID: Color] = [:]
        for task in tasks {
            result[task.id] = task.color.swiftUIColor ?? .accentColor
        }
        return result
    }

    private static func hasVisibleOpenEndedTimelineBlock(
        visibleDates: [Date],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        sprintFocusSessions: [SprintFocusSessionRecord],
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        let visibleDayStarts =
            visibleDates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        guard
            let visibleRangeStart = visibleDayStarts.first,
            let lastVisibleDayStart = visibleDayStarts.last,
            let visibleRangeEnd = calendar.date(byAdding: .day, value: 1, to: lastVisibleDayStart)
        else {
            return false
        }

        let hasActiveSleepBlock = sleepSessions.contains { session in
            guard let startedAt = session.startedAt, session.endedAt == nil else { return false }
            return intersectsVisibleRange(
                startedAt: startedAt,
                endedAt: referenceDate,
                visibleRangeStart: visibleRangeStart,
                visibleRangeEnd: visibleRangeEnd
            )
        }
        if hasActiveSleepBlock {
            return true
        }

        let hasActiveAwayBlock = awaySessions.contains { session in
            guard
                let startedAt = session.startedAt,
                session.isActive,
                session.plannedEndAt == nil
            else {
                return false
            }
            return intersectsVisibleRange(
                startedAt: startedAt,
                endedAt: referenceDate,
                visibleRangeStart: visibleRangeStart,
                visibleRangeEnd: visibleRangeEnd
            )
        }
        if hasActiveAwayBlock {
            return true
        }

        return sprintFocusSessions.contains { session in
            guard session.isActive else { return false }
            return intersectsVisibleRange(
                startedAt: session.startedAt,
                endedAt: referenceDate,
                visibleRangeStart: visibleRangeStart,
                visibleRangeEnd: visibleRangeEnd
            )
        }
    }

    private static func intersectsVisibleRange(
        startedAt: Date,
        endedAt: Date,
        visibleRangeStart: Date,
        visibleRangeEnd: Date
    ) -> Bool {
        max(startedAt, endedAt) >= visibleRangeStart && startedAt < visibleRangeEnd
    }
}

struct DayPlanTimelineRenderSnapshotKey: Equatable {
    var dataSnapshotID: UUID
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var selectedDayKey: String
    var focusedUnplannedCompletedDayKey: String?
    var referenceMinute: ReferenceMinute?
    var includesEvents: Bool
    var showsTimelineTasksInDayPlanner: Bool
    var hiddenTimelineActivityStorage: String
    var plannerBlocks: [DayPlanBlock]
    var plannerWeekBlocksByDayKey: [String: [DayPlanBlock]]

    init(
        dataSnapshotID: UUID,
        visibleDates: [Date],
        selectedDate: Date,
        focusedUnplannedCompletedDate: Date?,
        plannerBlocks: [DayPlanBlock],
        plannerWeekBlocksByDayKey: [String: [DayPlanBlock]],
        referenceDate: Date,
        refreshesEveryMinute: Bool,
        calendar: Calendar,
        includesEvents: Bool,
        showsTimelineTasksInDayPlanner: Bool,
        hiddenTimelineActivityStorage: String
    ) {
        self.dataSnapshotID = dataSnapshotID
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        visibleDayKeys =
            visibleDates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        selectedDayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        focusedUnplannedCompletedDayKey = focusedUnplannedCompletedDate.map {
            DayPlanStorage.dayKey(for: $0, calendar: calendar)
        }
        referenceMinute =
            refreshesEveryMinute
            ? ReferenceMinute(referenceDate: referenceDate, calendar: calendar)
            : nil
        self.includesEvents = includesEvents
        self.showsTimelineTasksInDayPlanner = showsTimelineTasksInDayPlanner
        self.hiddenTimelineActivityStorage = hiddenTimelineActivityStorage
        self.plannerBlocks = plannerBlocks
        self.plannerWeekBlocksByDayKey = plannerWeekBlocksByDayKey
    }

    struct ReferenceMinute: Equatable {
        var dayKey: String
        var minute: Int

        init(referenceDate: Date, calendar: Calendar) {
            dayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
            let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
            minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        }
    }
}
