import Foundation
import SwiftData

struct DayPlanFocusSessionBlock: Identifiable, Equatable {
    var sessionID: UUID
    var block: DayPlanBlock
    var durationMinutes: Int
    var opensTaskDetails: Bool = true

    var id: String {
        "\(block.dayKey)-\(sessionID.uuidString)-\(block.id.uuidString)"
    }
}

struct DayPlanSprintFocusBlock: Identifiable, Equatable {
    var sessionID: UUID
    var block: DayPlanBlock
    var interval: DayPlanBlockedInterval
    var isActive: Bool
    var isAllocatedToTask: Bool

    var id: String {
        "sprint-focus-\(sessionID.uuidString)-\(block.id.uuidString)-\(block.dayKey)"
    }

    var renderedDurationMinutes: Int {
        isActive ? max(interval.durationMinutes, 1) : block.durationMinutes
    }
}

struct DayPlanBlockedInterval: Equatable, Sendable {
    var dayKey: String
    var startMinute: Int
    var endMinute: Int
    var title: String

    var durationMinutes: Int {
        max(endMinute - startMinute, 0)
    }

    func overlaps(startMinute: Int, durationMinutes: Int) -> Bool {
        let targetStart = DayPlanBlock.clampedStartMinute(startMinute)
        let targetDuration = DayPlanBlock.clampedDuration(durationMinutes, startMinute: targetStart)
        let targetEnd = min(DayPlanBlock.minutesPerDay, targetStart + targetDuration)
        return max(targetStart, self.startMinute) < min(targetEnd, endMinute)
    }

    func overlaps(block: DayPlanBlock) -> Bool {
        max(block.startMinute, startMinute) < min(block.endMinute, endMinute)
    }
}

struct DayPlanFocusTaskAllocation: Equatable, Sendable {
    var taskID: UUID
    var minutes: Int
}

enum DayPlanFocusSessionBlocks {
    static func activeBlocksByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        sessions: [FocusSession],
        now: Date,
        calendar: Calendar,
        excluding plannedBlocks: [DayPlanBlock] = []
    ) -> [String: [DayPlanFocusSessionBlock]] {
        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard !visibleDayKeys.isEmpty else { return [:] }

        let blocks = activeBlocks(
            from: tasks,
            sessions: sessions,
            now: now,
            calendar: calendar,
            excluding: plannedBlocks
        )
        .filter { visibleDayKeys.contains($0.block.dayKey) }

        return Dictionary(grouping: blocks, by: \.block.dayKey)
            .mapValues {
                $0.sorted { lhs, rhs in
                    if lhs.block.startMinute != rhs.block.startMinute {
                        return lhs.block.startMinute < rhs.block.startMinute
                    }
                    return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
                }
            }
    }

    static func activeBlocks(
        from tasks: [RoutineTask],
        sessions: [FocusSession],
        now: Date,
        calendar: Calendar,
        excluding plannedBlocks: [DayPlanBlock] = []
    ) -> [DayPlanFocusSessionBlock] {
        let correctedPlannedBlocks = DayPlanFocusSessionPlannerSync.correctedActiveCountUpFocusSegmentBlocks(
            plannedBlocks,
            activeFocusSessions: sessions,
            referenceDate: now
        )
        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        let blocks = sessions.compactMap { session -> DayPlanFocusSessionBlock? in
            if session.isUnassigned {
                return planFocusBlock(
                    for: session,
                    now: now,
                    calendar: calendar,
                    excluding: correctedPlannedBlocks
                )
            }

            if session.isTagFocus {
                return tagFocusBlock(
                    for: session,
                    now: now,
                    calendar: calendar,
                    excluding: correctedPlannedBlocks
                )
            }

            guard let task = tasksByID[session.taskID] else { return nil }
            return taskFocusBlock(
                for: session,
                task: task,
                now: now,
                calendar: calendar,
                plannedBlocks: correctedPlannedBlocks
            )
        }

        return blocks.sorted { lhs, rhs in
            if lhs.block.startMinute != rhs.block.startMinute {
                return lhs.block.startMinute < rhs.block.startMinute
            }
            return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
        }
    }

    private static func taskFocusBlock(
        for session: FocusSession,
        task: RoutineTask,
        now: Date,
        calendar: Calendar,
        plannedBlocks: [DayPlanBlock]
    ) -> DayPlanFocusSessionBlock? {
        guard session.isTaskFocus,
            session.completedAt == nil,
            session.abandonedAt == nil,
            let startedAt = session.startedAt
        else { return nil }

        let segmentBlocks = DayPlanFocusSessionPlannerSync.focusSegmentBlocks(
            in: plannedBlocks,
            for: session
        )
        let latestSegmentBlock = segmentBlocks.last
        if session.isPaused, session.plannedDurationSeconds <= 0, latestSegmentBlock != nil {
            return nil
        }

        let dayKey = DayPlanStorage.dayKey(for: now, calendar: calendar)
        let renderStart = activeRenderStart(
            for: session,
            startedAt: startedAt,
            segmentBlocks: segmentBlocks,
            now: now,
            calendar: calendar
        )
        let blockID = activeBlockID(
            for: session,
            startedAt: startedAt,
            renderStart: renderStart,
            latestSegmentBlock: latestSegmentBlock
        )
        let startMinute = startMinute(for: renderStart, calendar: calendar)
        let elapsedSeconds = max(
            60,
            elapsedFocusSeconds(for: session, startedAt: startedAt, renderStart: renderStart, now: now)
        )
        let elapsedMinutes = max(1, Int(ceil(elapsedSeconds / 60)))
        let remainingMinutes = max(1, DayPlanBlock.minutesPerDay - startMinute)
        let durationMinutes = min(elapsedMinutes, remainingMinutes)
        let block = DayPlanBlock(
            id: blockID,
            taskID: task.id,
            dayKey: dayKey,
            startMinute: startMinute,
            durationMinutes: DayPlanBlock.clampedDuration(
                max(durationMinutes, DayPlanBlock.minimumDurationMinutes),
                startMinute: startMinute
            ),
            titleSnapshot: DayPlanTaskSorting.title(for: task),
            emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
            createdAt: renderStart,
            updatedAt: now
        )
        if session.plannedDurationSeconds > 0 {
            guard !isRepresentedByPlannerBlock(block, plannedBlocks: plannedBlocks) else {
                return nil
            }
        }

        return DayPlanFocusSessionBlock(
            sessionID: session.id,
            block: block,
            durationMinutes: durationMinutes
        )
    }

    private static func tagFocusBlock(
        for session: FocusSession,
        now: Date,
        calendar: Calendar,
        excluding plannedBlocks: [DayPlanBlock] = []
    ) -> DayPlanFocusSessionBlock? {
        guard session.completedAt == nil,
            session.abandonedAt == nil,
            let startedAt = session.startedAt,
            let tagTitle = session.focusTagTitle
        else { return nil }

        let segmentBlocks = DayPlanFocusSessionPlannerSync.focusSegmentBlocks(
            in: plannedBlocks,
            for: session
        )
        let latestSegmentBlock = segmentBlocks.last
        if session.isPaused, session.plannedDurationSeconds <= 0, latestSegmentBlock != nil {
            return nil
        }

        let dayKey = DayPlanStorage.dayKey(for: now, calendar: calendar)
        let renderStart = activeRenderStart(
            for: session,
            startedAt: startedAt,
            segmentBlocks: segmentBlocks,
            now: now,
            calendar: calendar
        )
        let blockID = activeBlockID(
            for: session,
            startedAt: startedAt,
            renderStart: renderStart,
            latestSegmentBlock: latestSegmentBlock
        )
        let startMinute = startMinute(for: renderStart, calendar: calendar)
        let elapsedSeconds = max(
            60,
            elapsedFocusSeconds(for: session, startedAt: startedAt, renderStart: renderStart, now: now)
        )
        let elapsedMinutes = max(1, Int(ceil(elapsedSeconds / 60)))
        let remainingMinutes = max(1, DayPlanBlock.minutesPerDay - startMinute)
        let durationMinutes = min(elapsedMinutes, remainingMinutes)
        let block = DayPlanBlock(
            id: blockID,
            taskID: FocusSession.unassignedTaskID,
            dayKey: dayKey,
            startMinute: startMinute,
            durationMinutes: DayPlanBlock.clampedDuration(
                max(durationMinutes, DayPlanBlock.minimumDurationMinutes),
                startMinute: startMinute
            ),
            titleSnapshot: tagTitle,
            emojiSnapshot: nil,
            createdAt: renderStart,
            updatedAt: now
        )
        if session.plannedDurationSeconds > 0 {
            guard !isRepresentedByPlannerBlock(block, plannedBlocks: plannedBlocks) else {
                return nil
            }
        }

        return DayPlanFocusSessionBlock(
            sessionID: session.id,
            block: block,
            durationMinutes: durationMinutes,
            opensTaskDetails: false
        )
    }

    private static func planFocusBlock(
        for session: FocusSession,
        now: Date,
        calendar: Calendar,
        excluding plannedBlocks: [DayPlanBlock] = []
    ) -> DayPlanFocusSessionBlock? {
        guard session.abandonedAt == nil,
            let startedAt = session.startedAt,
            calendar.isDate(startedAt, inSameDayAs: now)
        else {
            return nil
        }

        let renderEnd = session.finishedAt ?? now
        guard renderEnd >= startedAt else { return nil }

        let allocatedMinutes = planFocusAllocatedMinutes(
            for: session,
            plannedBlocks: plannedBlocks
        )
        let elapsedSeconds = session.activeDurationSeconds(at: renderEnd)
        let allocatedSeconds = TimeInterval(max(0, allocatedMinutes) * 60)
        let remainingSeconds = elapsedSeconds - allocatedSeconds
        guard remainingSeconds > 0 else { return nil }

        let renderStart =
            calendar.date(
                byAdding: .minute,
                value: allocatedMinutes,
                to: startedAt
            ) ?? startedAt
        guard calendar.isDate(renderStart, inSameDayAs: startedAt) else {
            return nil
        }

        let dayKey = DayPlanStorage.dayKey(for: renderStart, calendar: calendar)
        let startMinute = startMinute(for: renderStart, calendar: calendar)
        let elapsedMinutes = max(1, Int(ceil(remainingSeconds / 60)))
        let remainingMinutes = max(1, DayPlanBlock.minutesPerDay - startMinute)
        let durationMinutes = min(elapsedMinutes, remainingMinutes)
        let block = DayPlanBlock(
            id: session.id,
            taskID: FocusSession.unassignedTaskID,
            dayKey: dayKey,
            startMinute: startMinute,
            durationMinutes: DayPlanBlock.clampedDuration(
                max(durationMinutes, DayPlanBlock.minimumStoredDurationMinutes),
                startMinute: startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            ),
            titleSnapshot: "Plan Focus",
            emojiSnapshot: nil,
            createdAt: renderStart,
            updatedAt: renderEnd,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )

        return DayPlanFocusSessionBlock(
            sessionID: session.id,
            block: block,
            durationMinutes: durationMinutes,
            opensTaskDetails: false
        )
    }

    private static func planFocusAllocatedMinutes(
        for session: FocusSession,
        plannedBlocks: [DayPlanBlock]
    ) -> Int {
        plannedBlocks.reduce(0) { total, block in
            guard
                block.id
                    == DayPlanFocusSessionPlannerSync.allocationBlockID(
                        sessionID: session.id,
                        taskID: block.taskID
                    )
            else {
                return total
            }
            return total + max(0, block.durationMinutes)
        }
    }

    private static func startMinute(for timestamp: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
    }

    private static func renderStart(for startedAt: Date, now: Date, calendar: Calendar) -> Date {
        if startedAt > now {
            return now
        }

        guard calendar.isDate(startedAt, inSameDayAs: now) else {
            return calendar.startOfDay(for: now)
        }

        return startedAt
    }

    private static func elapsedFocusSeconds(
        for session: FocusSession,
        startedAt: Date,
        renderStart: Date,
        now: Date
    ) -> TimeInterval {
        guard renderStart == startedAt else {
            let renderEnd = session.pausedAt ?? now
            return max(0, renderEnd.timeIntervalSince(renderStart))
        }

        return session.activeDurationSeconds(at: now)
    }

    private static func activeRenderStart(
        for session: FocusSession,
        startedAt: Date,
        segmentBlocks: [DayPlanBlock],
        now: Date,
        calendar: Calendar
    ) -> Date {
        let sessionRenderStart = renderStart(for: startedAt, now: now, calendar: calendar)
        let latestSegmentBlock = segmentBlocks.last
        guard session.plannedDurationSeconds <= 0,
            let latestSegmentBlock
        else {
            return sessionRenderStart
        }

        if latestSegmentBlock.createdAt > sessionRenderStart {
            return renderStart(for: latestSegmentBlock.createdAt, now: now, calendar: calendar)
        }

        if let inferredStart = inferredCurrentSegmentStart(
            for: session,
            segmentBlocks: segmentBlocks,
            now: now
        ) {
            return renderStart(for: inferredStart, now: now, calendar: calendar)
        }

        return sessionRenderStart
    }

    private static func activeBlockID(
        for session: FocusSession,
        startedAt: Date,
        renderStart: Date,
        latestSegmentBlock: DayPlanBlock?
    ) -> UUID {
        if let latestSegmentBlock {
            if latestSegmentBlock.createdAt == renderStart {
                return latestSegmentBlock.id
            }
        }

        if renderStart == startedAt {
            return session.id
        }

        return DayPlanFocusSessionPlannerSync.focusSegmentBlockID(
            sessionID: session.id,
            segmentStartedAt: renderStart
        )
    }

    private static func inferredCurrentSegmentStart(
        for session: FocusSession,
        segmentBlocks: [DayPlanBlock],
        now: Date
    ) -> Date? {
        guard session.pausedAt == nil,
            session.accumulatedPausedSeconds > 0,
            segmentBlocks.count == 1,
            let segmentBlock = segmentBlocks.first,
            segmentBlock.id == session.id
        else {
            return nil
        }

        let activeSeconds = session.activeDurationSeconds(at: now)
        let storedSeconds = TimeInterval(max(0, segmentBlock.durationMinutes) * 60)
        let currentSegmentSeconds = max(0, activeSeconds - storedSeconds)
        guard currentSegmentSeconds > 0 else { return nil }

        let inferredStart = now.addingTimeInterval(-currentSegmentSeconds)
        return max(inferredStart, segmentBlock.updatedAt)
    }

    private static func isRepresentedByPlannerBlock(
        _ focusBlock: DayPlanBlock,
        plannedBlocks: [DayPlanBlock]
    ) -> Bool {
        plannedBlocks.contains { plannedBlock in
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
    }
}
