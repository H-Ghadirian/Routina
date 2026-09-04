import Foundation
import SwiftData

extension DayPlanFocusSessionPlannerSync {
    @discardableResult
    static func saveStartedFocusBlock(
        for task: RoutineTask,
        session: FocusSession,
        startedAt: Date,
        durationSeconds: TimeInterval,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        let block = plannerBlock(
            for: task,
            session: session,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            calendar: calendar
        )
        var blocks = DayPlanStorage.loadBlocks(forDayKey: block.dayKey, context: context)

        if let existingBlock = blocks.first(where: { $0.id == block.id }) {
            return existingBlock
        }

        if durationSeconds > 0 {
            if let existingBlock = blocks.first(where: { representsFocusBlock($0, focusBlock: block) }) {
                return existingBlock
            }
        }

        blocks.append(block)
        DayPlanStorage.saveBlocks(blocks, forDayKey: block.dayKey, context: context)
        return block
    }

    @discardableResult
    static func saveStartedTagFocusBlock(
        tagName: String,
        session: FocusSession,
        startedAt: Date,
        durationSeconds: TimeInterval,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        let block = tagPlannerBlock(
            tagName: tagName,
            session: session,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            calendar: calendar
        )
        var blocks = DayPlanStorage.loadBlocks(forDayKey: block.dayKey, context: context)

        if let existingBlock = blocks.first(where: { $0.id == block.id }) {
            return existingBlock
        }

        if durationSeconds > 0 {
            if let existingBlock = blocks.first(where: { representsFocusBlock($0, focusBlock: block) }) {
                return existingBlock
            }
        }

        blocks.append(block)
        DayPlanStorage.saveBlocks(blocks, forDayKey: block.dayKey, context: context)
        return block
    }

    @discardableResult
    static func saveEndedCountUpFocusBlock(
        for task: RoutineTask,
        session: FocusSession,
        endedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard session.plannedDurationSeconds <= 0,
            let startedAt = session.startedAt
        else {
            return nil
        }

        let storedSegments = focusSegmentBlocks(for: session, context: context)
        let currentSegmentStartedAt = countUpSegmentStart(
            for: session,
            storedSegments: storedSegments,
            segmentEndedAt: endedAt,
            canInferCurrentSegment: session.accumulatedPausedSeconds > 0
        )
        if let segmentStartedAt = currentSegmentStartedAt {
            if segmentStartedAt > startedAt {
                repairOvergrownCompletedSegments(
                    for: session,
                    storedSegments: storedSegments,
                    currentSegmentStartedAt: segmentStartedAt,
                    segmentEndedAt: endedAt,
                    context: context
                )
                let durationSeconds = max(60, endedAt.timeIntervalSince(segmentStartedAt))
                let blocks = focusSegmentBlocks(
                    session: session,
                    taskID: task.id,
                    title: DayPlanTaskSorting.title(for: task),
                    emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                    segmentStartedAt: segmentStartedAt,
                    durationSeconds: durationSeconds,
                    calendar: calendar
                )
                _ = upsertBlocks(blocks, context: context)
                return blocks.first
            }
        }

        let elapsedSeconds = max(60, session.activeDurationSeconds(at: endedAt))
        let blocks = focusSegmentBlocks(
            session: session,
            taskID: task.id,
            title: DayPlanTaskSorting.title(for: task),
            emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
            segmentStartedAt: startedAt,
            durationSeconds: elapsedSeconds,
            calendar: calendar,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        _ = upsertBlocks(blocks, context: context)
        return blocks.first
    }

    @discardableResult
    static func saveEndedCountUpTagFocusBlock(
        tagName: String,
        session: FocusSession,
        endedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard session.plannedDurationSeconds <= 0,
            let startedAt = session.startedAt
        else {
            return nil
        }

        let storedSegments = focusSegmentBlocks(for: session, context: context)
        let currentSegmentStartedAt = countUpSegmentStart(
            for: session,
            storedSegments: storedSegments,
            segmentEndedAt: endedAt,
            canInferCurrentSegment: session.accumulatedPausedSeconds > 0
        )
        if let segmentStartedAt = currentSegmentStartedAt {
            if segmentStartedAt > startedAt {
                repairOvergrownCompletedSegments(
                    for: session,
                    storedSegments: storedSegments,
                    currentSegmentStartedAt: segmentStartedAt,
                    segmentEndedAt: endedAt,
                    context: context
                )
                let durationSeconds = max(60, endedAt.timeIntervalSince(segmentStartedAt))
                let title = RoutineTag.cleaned(tagName).map { "#\($0)" } ?? "#Tag"
                let blocks = focusSegmentBlocks(
                    session: session,
                    taskID: FocusSession.unassignedTaskID,
                    title: title,
                    emoji: nil,
                    segmentStartedAt: segmentStartedAt,
                    durationSeconds: durationSeconds,
                    calendar: calendar
                )
                _ = upsertBlocks(blocks, context: context)
                return blocks.first
            }
        }

        let elapsedSeconds = max(60, session.activeDurationSeconds(at: endedAt))
        let blocks = focusSegmentBlocks(
            session: session,
            taskID: FocusSession.unassignedTaskID,
            title: RoutineTag.cleaned(tagName).map { "#\($0)" } ?? "#Tag",
            emoji: nil,
            segmentStartedAt: startedAt,
            durationSeconds: elapsedSeconds,
            calendar: calendar,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        _ = upsertBlocks(blocks, context: context)
        return blocks.first
    }

    @discardableResult
    static func saveCompletedFocusBlock(
        for task: RoutineTask,
        session: FocusSession,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard let startedAt = session.startedAt,
            let endedAt = session.completedAt
        else {
            return nil
        }

        let elapsedSeconds = max(60, session.activeDurationSeconds(at: endedAt))
        let blocks = focusSegmentBlocks(
            session: session,
            taskID: task.id,
            title: DayPlanTaskSorting.title(for: task),
            emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
            segmentStartedAt: startedAt,
            durationSeconds: elapsedSeconds,
            calendar: calendar,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        _ = upsertBlocks(blocks, context: context)
        return blocks.first
    }

    @discardableResult
    static func removeFocusBlock(
        for session: FocusSession,
        context: ModelContext
    ) -> Bool {
        do {
            let records = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
                .filter { record in
                    record.id == session.id || isFocusSegmentBlock(record.detachedBlock, for: session)
                }
            guard !records.isEmpty else {
                return false
            }

            for record in records {
                context.delete(record)
            }
            try context.save()
            return true
        } catch {
            NSLog("Failed to remove focus planner block for \(session.id): \(error.localizedDescription)")
            return false
        }
    }

    static func plannerBlock(
        for task: RoutineTask,
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
        return DayPlanBlock(
            id: session.id,
            taskID: task.id,
            dayKey: DayPlanStorage.dayKey(for: startedAt, calendar: calendar),
            startMinute: startMinute,
            durationMinutes: durationMinutes(
                durationSeconds: durationSeconds,
                startMinute: startMinute,
                minimumDurationMinutes: minimumDurationMinutes
            ),
            titleSnapshot: DayPlanTaskSorting.title(for: task),
            emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
            createdAt: startedAt,
            updatedAt: startedAt,
            minimumDurationMinutes: minimumDurationMinutes
        )
    }

    static func focusSegmentBlocks(for session: FocusSession, context: ModelContext) -> [DayPlanBlock] {
        do {
            let records = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
            return focusSegmentBlocks(in: records.map(\.detachedBlock), for: session)
        } catch {
            NSLog("Failed to load focus planner segments for \(session.id): \(error.localizedDescription)")
            return []
        }
    }

    struct FocusPauseResumeAction {
        var kind: RoutinaDeviceActionKind
        var timestamp: Date
    }

    struct FocusSegmentInterval {
        var startedAt: Date
        var endedAt: Date?

        var durationSeconds: TimeInterval {
            guard let endedAt else {
                return 60
            }

            return max(60, endedAt.timeIntervalSince(startedAt))
        }
    }

}
