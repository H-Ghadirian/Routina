import Combine
import Foundation

final class DayPlanDayTaskListItemsCache: ObservableObject {
    private struct Signature: Hashable {
        var dataSnapshotID: UUID
        var dayKey: String
        var calendarIdentifier: String
        var timeZoneIdentifier: String
        var firstWeekday: Int
        var minimumDaysInFirstWeek: Int
        var visibilitySignature: DayPlanDayTaskListVisibilitySignature
        var excludedTaskIDs: Set<UUID>
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
            visibilitySignature: DayPlanDayTaskListVisibilitySignature,
            excludedTaskIDs: Set<UUID>
        ) {
            self.dataSnapshotID = dataSnapshotID
            dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            calendarIdentifier = String(describing: calendar.identifier)
            timeZoneIdentifier = calendar.timeZone.identifier
            firstWeekday = calendar.firstWeekday
            minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
            self.visibilitySignature = visibilitySignature
            self.excludedTaskIDs = excludedTaskIDs
            completionReferenceMinute = Int(referenceDate.timeIntervalSinceReferenceDate / 60)
            self.timedBlocks = timedBlocks.map(TimedBlockSignature.init(block:))
            timelineActivities =
                timelineActivityBlocks
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
        var isConfirmedAssumedDone: Bool

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
            isConfirmedAssumedDone = activity.isConfirmedAssumedDone
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
        excludedTaskIDs: Set<UUID> = [],
        visibilityCache: DayPlanPlannedDateTaskVisibilityCache? = nil
    ) -> [DayPlanDayTaskListItem] {
        let signature = Signature(
            dataSnapshotID: dataSnapshotID,
            date: date,
            timedBlocks: timedBlocks,
            timelineActivityBlocks: timelineActivityBlocks,
            referenceDate: referenceDate,
            calendar: calendar,
            visibilitySignature: visibilitySignature,
            excludedTaskIDs: excludedTaskIDs
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
            excludedTaskIDs: excludedTaskIDs,
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
