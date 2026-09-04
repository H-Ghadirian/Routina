import Foundation
import SwiftData

extension DayPlanFocusSessionPlannerSync {
    @discardableResult
    static func savePausedCountUpFocusSegment(
        for task: RoutineTask,
        session: FocusSession,
        pausedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        savePausedCountUpFocusSegment(
            session: session,
            taskID: task.id,
            title: DayPlanTaskSorting.title(for: task),
            emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
            pausedAt: pausedAt,
            calendar: calendar,
            context: context
        )
    }

    @discardableResult
    static func savePausedCountUpTagFocusSegment(
        tagName: String,
        session: FocusSession,
        pausedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        let title = RoutineTag.cleaned(tagName).map { "#\($0)" } ?? "#Tag"
        return savePausedCountUpFocusSegment(
            session: session,
            taskID: FocusSession.unassignedTaskID,
            title: title,
            emoji: nil,
            pausedAt: pausedAt,
            calendar: calendar,
            context: context
        )
    }

    @discardableResult
    static func saveResumedCountUpFocusSegment(
        for task: RoutineTask,
        session: FocusSession,
        resumedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        saveResumedCountUpFocusSegment(
            session: session,
            taskID: task.id,
            title: DayPlanTaskSorting.title(for: task),
            emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
            resumedAt: resumedAt,
            calendar: calendar,
            context: context
        )
    }

    @discardableResult
    static func saveResumedCountUpTagFocusSegment(
        tagName: String,
        session: FocusSession,
        resumedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        let title = RoutineTag.cleaned(tagName).map { "#\($0)" } ?? "#Tag"
        return saveResumedCountUpFocusSegment(
            session: session,
            taskID: FocusSession.unassignedTaskID,
            title: title,
            emoji: nil,
            resumedAt: resumedAt,
            calendar: calendar,
            context: context
        )
    }

    @discardableResult
    static func reconcileCountUpFocusSegments(
        for sessions: [FocusSession],
        tasks: [RoutineTask],
        calendar: Calendar,
        context: ModelContext
    ) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        var reconciledBlocks: [DayPlanBlock] = []
        for session in sessions {
            guard session.plannedDurationSeconds <= 0,
                session.abandonedAt == nil,
                let startedAt = session.startedAt,
                session.isTaskFocus || session.isTagFocus
            else {
                continue
            }

            let taskID: UUID
            let title: String
            let emoji: String?
            if session.isTagFocus {
                taskID = FocusSession.unassignedTaskID
                title = session.focusTagTitle ?? "#Tag"
                emoji = nil
            } else if let task = tasksByID[session.taskID] {
                taskID = task.id
                title = DayPlanTaskSorting.title(for: task)
                emoji = CalendarTaskImportSupport.displayEmoji(for: task.emoji)
            } else {
                continue
            }

            let actions = focusPauseResumeActionLogs(for: session.id, context: context)
            let segments = focusSegments(
                startedAt: startedAt,
                completedAt: session.completedAt,
                pausedAt: session.pausedAt,
                actions: actions
            )
            guard !segments.isEmpty else { continue }

            reconciledBlocks.append(
                contentsOf: segments.flatMap { segment in
                    focusSegmentBlocks(
                        session: session,
                        taskID: taskID,
                        title: title,
                        emoji: emoji,
                        segmentStartedAt: segment.startedAt,
                        durationSeconds: segment.durationSeconds,
                        calendar: calendar
                    )
                }
            )
        }

        return upsertBlocks(reconciledBlocks, context: context)
    }

    @discardableResult
    static func upsertBlocks(
        _ incomingBlocks: [DayPlanBlock],
        context: ModelContext
    ) -> Int {
        guard !incomingBlocks.isEmpty else { return 0 }

        let incomingByDayKey = Dictionary(grouping: incomingBlocks, by: \.dayKey)
        var persistedDayCount = 0

        for dayKey in incomingByDayKey.keys.sorted() {
            guard let incomingDayBlocks = incomingByDayKey[dayKey] else { continue }

            var storedBlocks = DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
            var storedIndexByID: [UUID: Int] = [:]
            for (index, block) in storedBlocks.enumerated() {
                storedIndexByID[block.id] = index
            }

            var didChange = false
            for block in incomingDayBlocks {
                if let index = storedIndexByID[block.id] {
                    guard storedBlocks[index] != block else { continue }
                    storedBlocks[index] = block
                    didChange = true
                } else {
                    storedIndexByID[block.id] = storedBlocks.count
                    storedBlocks.append(block)
                    didChange = true
                }
            }

            guard didChange else { continue }
            DayPlanStorage.saveBlocks(storedBlocks, forDayKey: dayKey, context: context)
            persistedDayCount += 1
        }

        return persistedDayCount
    }
}
