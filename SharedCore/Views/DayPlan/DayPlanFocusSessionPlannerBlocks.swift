import Foundation
import SwiftData

extension DayPlanFocusSessionPlannerSync {
    static func tagPlannerBlock(
        tagName: String,
        session: FocusSession,
        startedAt: Date,
        durationSeconds: TimeInterval,
        calendar: Calendar,
        minimumDurationMinutes: Int? = nil
    ) -> DayPlanBlock {
        let minimumDurationMinutes =
            minimumDurationMinutes
            ?? (durationSeconds > 0 ? DayPlanBlock.minimumDurationMinutes : DayPlanBlock.minimumStoredDurationMinutes)
        let startMinute = startMinute(
            for: startedAt,
            calendar: calendar,
            minimumDurationMinutes: minimumDurationMinutes
        )
        let title = RoutineTag.cleaned(tagName).map { "#\($0)" } ?? "#Tag"
        return DayPlanBlock(
            id: session.id,
            taskID: FocusSession.unassignedTaskID,
            dayKey: DayPlanStorage.dayKey(for: startedAt, calendar: calendar),
            startMinute: startMinute,
            durationMinutes: durationMinutes(
                durationSeconds: durationSeconds,
                startMinute: startMinute,
                minimumDurationMinutes: minimumDurationMinutes
            ),
            titleSnapshot: title,
            emojiSnapshot: nil,
            createdAt: startedAt,
            updatedAt: startedAt,
            minimumDurationMinutes: minimumDurationMinutes
        )
    }

    static func startMinute(
        for timestamp: Date,
        calendar: Calendar,
        minimumDurationMinutes: Int = DayPlanBlock.minimumDurationMinutes
    ) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        return DayPlanBlock.clampedStartMinute(
            ((components.hour ?? 0) * 60) + (components.minute ?? 0),
            minimumDurationMinutes: minimumDurationMinutes
        )
    }

    static func durationMinutes(
        durationSeconds: TimeInterval,
        startMinute: Int,
        minimumDurationMinutes: Int
    ) -> Int {
        let rawMinutes = durationSeconds > 0 ? max(1, Int(ceil(durationSeconds / 60))) : 1
        return DayPlanBlock.clampedDuration(
            rawMinutes,
            startMinute: startMinute,
            minimumDurationMinutes: minimumDurationMinutes
        )
    }

    static func representsFocusBlock(
        _ plannedBlock: DayPlanBlock,
        focusBlock: DayPlanBlock
    ) -> Bool {
        if plannedBlock.id == focusBlock.id {
            return true
        }

        guard plannedBlock.taskID == focusBlock.taskID,
            plannedBlock.dayKey == focusBlock.dayKey
        else {
            return false
        }

        return plannedBlock.startMinute < focusBlock.endMinute
            && focusBlock.startMinute < plannedBlock.endMinute
    }

    static func upsertBlock(_ block: DayPlanBlock, context: ModelContext) {
        upsertBlocks([block], context: context)
    }

    static func deleteBlock(id: UUID, dayKey: String, context: ModelContext) {
        var blocks = DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
        blocks.removeAll { $0.id == id }
        DayPlanStorage.saveBlocks(blocks, forDayKey: dayKey, context: context)
    }

    static func timeSpentChangeEntry(
        previousDurationMinutes: Int?,
        durationMinutes: Int?
    ) -> RoutineTaskChangeLogEntry {
        let kind: RoutineTaskChangeKind
        switch (previousDurationMinutes, durationMinutes) {
        case (nil, .some):
            kind = .timeSpentAdded
        case (.some, nil):
            kind = .timeSpentRemoved
        default:
            kind = .timeSpentChanged
        }

        return RoutineTaskChangeLogEntry(
            kind: kind,
            previousValue: previousDurationMinutes.map(String.init),
            newValue: durationMinutes.map(String.init),
            durationMinutes: durationMinutes
        )
    }
}
