import SwiftData
import SwiftUI

struct DayPlanTimelineRenderSnapshot {
    var visibleDates: [Date]
    var tasks: [RoutineTask]
    var logs: [RoutineLog]
    var sleepSessions: [SleepSession]
    var awaySessions: [AwaySession]
    var events: [RoutineEvent]
    var sprintFocusSessions: [SprintFocusSessionRecord]
    var sprintFocusAllocations: [SprintFocusAllocationRecord]
    var boardSprints: [BoardSprintRecord]
    var focusSessions: [FocusSession]
    var activeSprintFocusSessions: [SprintFocusSessionRecord]
    var plannedBlocksByDayKey: [String: [DayPlanBlock]]
    var rawPlannedBlocks: [DayPlanBlock]
    var sleepBlocksByDayKey: [String: [DayPlanSleepBlock]]
    var linkedAwayBlocksByDayKey: [String: [DayPlanAwayBlock]]
    var sprintFocusBlocksByDayKey: [String: [DayPlanSprintFocusBlock]]
    var eventBlocksByDayKey: [String: [DayPlanEventBlock]]
    var blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    var timelineBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    var unplaceableAutomaticSuggestionBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    var automaticSuggestionBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    var assumedDoneSummaryBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    var allDayBlocks: [DayPlanAllDayBlock]
    var visibleBlockContext: DayPlanVisibleBlockContext
    var selectedDayBlockedMinutes: Int
    var tintsByTaskID: [UUID: Color]
    var activeFocusRenderSessions: [FocusSession]
    var planFocusAllocatedMinutesBySessionID: [UUID: Int]
}

struct DayPlanCalendarTaskFilterSnapshot {
    var allTaskIDs: Set<UUID>
    var currentTasks: [RoutineTask]
    var currentTaskIDs: Set<UUID>
    var calendarListHiddenTaskIDs: Set<UUID>

    var isFilterActive: Bool {
        currentTaskIDs != allTaskIDs
    }
}

@MainActor
final class DayPlanCalendarTaskFilterCache: ObservableObject {
    private struct Key: Equatable {
        var dataSnapshotID: UUID
        var filterSeed: Int
        var revealsHiddenCalendarListTasks: Bool
    }

    private var cachedKey: Key?
    private var cachedSnapshot: DayPlanCalendarTaskFilterSnapshot?

    func snapshot(
        dataSnapshotID: UUID,
        tasks: [RoutineTask],
        filterSeed: Int,
        revealsHiddenCalendarListTasks: Bool,
        filter: (RoutineTask) -> Bool
    ) -> DayPlanCalendarTaskFilterSnapshot {
        let key = Key(
            dataSnapshotID: dataSnapshotID,
            filterSeed: filterSeed,
            revealsHiddenCalendarListTasks: revealsHiddenCalendarListTasks
        )
        if cachedKey == key, let cachedSnapshot {
            return cachedSnapshot
        }

        let allTaskIDs = Set(tasks.map(\.id))
        let currentTasks = filterSeed == 0 ? tasks : tasks.filter(filter)
        let calendarListHiddenTaskIDs: Set<UUID> =
            revealsHiddenCalendarListTasks
            ? []
            : Set(
                currentTasks.lazy
                    .filter {
                        RoutineFlag.contains(
                            RoutineFlagRuleKind.hideFromCalendarList.builtInFlagName,
                            in: $0.flags
                        )
                    }
                    .map(\.id)
            )
        let snapshot = DayPlanCalendarTaskFilterSnapshot(
            allTaskIDs: allTaskIDs,
            currentTasks: currentTasks,
            currentTaskIDs: filterSeed == 0 ? allTaskIDs : Set(currentTasks.map(\.id)),
            calendarListHiddenTaskIDs: calendarListHiddenTaskIDs
        )
        cachedKey = key
        cachedSnapshot = snapshot
        return snapshot
    }
}
