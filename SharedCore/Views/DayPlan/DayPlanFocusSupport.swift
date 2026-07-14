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

            guard session.isTaskFocus,
                  session.completedAt == nil,
                  session.abandonedAt == nil,
                  let startedAt = session.startedAt,
                  let task = tasksByID[session.taskID]
            else { return nil }

            let segmentBlocks = DayPlanFocusSessionPlannerSync.focusSegmentBlocks(
                in: correctedPlannedBlocks,
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
                guard !isRepresentedByPlannerBlock(block, plannedBlocks: correctedPlannedBlocks) else {
                    return nil
                }
            }

            return DayPlanFocusSessionBlock(
                sessionID: session.id,
                block: block,
                durationMinutes: durationMinutes
            )
        }

        return blocks.sorted { lhs, rhs in
            if lhs.block.startMinute != rhs.block.startMinute {
                return lhs.block.startMinute < rhs.block.startMinute
            }
            return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
        }
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
              calendar.isDate(startedAt, inSameDayAs: now) else {
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

        let renderStart = calendar.date(
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
            guard block.id == DayPlanFocusSessionPlannerSync.allocationBlockID(
                sessionID: session.id,
                taskID: block.taskID
            ) else {
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
              let latestSegmentBlock else {
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
        if let latestSegmentBlock,
           latestSegmentBlock.createdAt == renderStart {
            return latestSegmentBlock.id
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
              segmentBlock.id == session.id else {
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
                  plannedBlock.dayKey == focusBlock.dayKey else {
                return false
            }

            return plannedBlock.startMinute < focusBlock.endMinute
                && focusBlock.startMinute < plannedBlock.endMinute
        }
    }
}

enum DayPlanFocusSessionPlannerSync {
    static func allocationBlockID(sessionID: UUID, taskID: UUID) -> UUID {
        let sessionBytes = sessionID.uuid
        let taskBytes = taskID.uuid
        return UUID(uuid: (
            sessionBytes.0 ^ taskBytes.15,
            sessionBytes.1 ^ taskBytes.14,
            sessionBytes.2 ^ taskBytes.13,
            sessionBytes.3 ^ taskBytes.12,
            sessionBytes.4 ^ taskBytes.11,
            sessionBytes.5 ^ taskBytes.10,
            sessionBytes.6 ^ taskBytes.9,
            sessionBytes.7 ^ taskBytes.8,
            sessionBytes.8 ^ taskBytes.7,
            sessionBytes.9 ^ taskBytes.6,
            sessionBytes.10 ^ taskBytes.5,
            sessionBytes.11 ^ taskBytes.4,
            sessionBytes.12 ^ taskBytes.3,
            sessionBytes.13 ^ taskBytes.2,
            sessionBytes.14 ^ taskBytes.1,
            sessionBytes.15 ^ taskBytes.0
        ))
    }

    static func focusSegmentBlocks(
        in blocks: [DayPlanBlock],
        for session: FocusSession
    ) -> [DayPlanBlock] {
        blocks
            .filter { isFocusSegmentBlock($0, for: session) }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.startMinute < rhs.startMinute
            }
    }

    static func latestFocusSegmentBlock(
        in blocks: [DayPlanBlock],
        for session: FocusSession
    ) -> DayPlanBlock? {
        focusSegmentBlocks(in: blocks, for: session).last
    }

    static func correctedActiveCountUpFocusSegmentBlocks(
        _ blocks: [DayPlanBlock],
        activeFocusSessions: [FocusSession],
        referenceDate: Date
    ) -> [DayPlanBlock] {
        guard !blocks.isEmpty, !activeFocusSessions.isEmpty else { return blocks }

        var correctedBlocks = blocks
        for session in activeFocusSessions {
            let corrections = correctedCompletedSegmentDurations(
                in: correctedBlocks,
                for: session,
                referenceDate: referenceDate
            )
            guard !corrections.isEmpty else { continue }

            correctedBlocks = correctedBlocks.map { block in
                guard let durationMinutes = corrections[block.id] else {
                    return block
                }

                return copyBlock(block, durationMinutes: durationMinutes)
            }
        }

        return correctedBlocks
    }

    static func isFocusSegmentBlock(
        _ block: DayPlanBlock,
        for session: FocusSession
    ) -> Bool {
        guard session.plannedDurationSeconds <= 0,
              (session.isTaskFocus || session.isTagFocus),
              let startedAt = session.startedAt,
              block.taskID == session.taskID else {
            return false
        }

        if block.id == session.id {
            return true
        }

        guard block.createdAt >= startedAt else {
            return false
        }

        return block.id == focusSegmentBlockID(
            sessionID: session.id,
            segmentStartedAt: block.createdAt
        )
    }

    private static func correctedCompletedSegmentDurations(
        in blocks: [DayPlanBlock],
        for session: FocusSession,
        referenceDate: Date
    ) -> [UUID: Int] {
        guard session.plannedDurationSeconds <= 0,
              session.completedAt == nil,
              session.abandonedAt == nil,
              session.accumulatedPausedSeconds > 0,
              session.isTaskFocus || session.isTagFocus else {
            return [:]
        }

        let segments = focusSegmentBlocks(in: blocks, for: session)
        guard segments.count > 1,
              let currentSegment = segments.last else {
            return [:]
        }

        let renderEnd = session.pausedAt ?? referenceDate
        guard renderEnd >= currentSegment.createdAt else {
            return [:]
        }

        let activeSeconds = session.activeDurationSeconds(at: renderEnd)
        let currentSegmentSeconds = max(0, renderEnd.timeIntervalSince(currentSegment.createdAt))
        let completedBudgetSeconds = max(0, activeSeconds - currentSegmentSeconds)
        return completedSegmentDurationCorrections(
            Array(segments.dropLast()),
            budgetSeconds: completedBudgetSeconds
        )
    }

    private static func copyBlock(_ block: DayPlanBlock, durationMinutes: Int) -> DayPlanBlock {
        DayPlanBlock(
            id: block.id,
            taskID: block.taskID,
            dayKey: block.dayKey,
            startMinute: block.startMinute,
            durationMinutes: durationMinutes,
            titleSnapshot: block.titleSnapshot,
            emojiSnapshot: block.emojiSnapshot,
            createdAt: block.createdAt,
            updatedAt: block.updatedAt,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
    }

    private static func completedSegmentDurationCorrections(
        _ segments: [DayPlanBlock],
        budgetSeconds: TimeInterval
    ) -> [UUID: Int] {
        let budgetMinutes = Int(ceil(max(0, budgetSeconds) / 60))
        guard budgetMinutes > 0, !segments.isEmpty else {
            return [:]
        }

        let originalMinutes = segments.reduce(0) { total, segment in
            total + max(DayPlanBlock.minimumStoredDurationMinutes, segment.durationMinutes)
        }
        guard originalMinutes > budgetMinutes else {
            return [:]
        }

        var overageMinutes = originalMinutes - budgetMinutes
        var correctedDurations: [UUID: Int] = [:]
        for segment in segments {
            guard overageMinutes > 0 else { break }

            let originalDuration = max(DayPlanBlock.minimumStoredDurationMinutes, segment.durationMinutes)
            let reducibleMinutes = max(0, originalDuration - DayPlanBlock.minimumStoredDurationMinutes)
            let reduction = min(overageMinutes, reducibleMinutes)
            guard reduction > 0 else { continue }

            correctedDurations[segment.id] = originalDuration - reduction
            overageMinutes -= reduction
        }

        return correctedDurations
    }

    @discardableResult
    static func savePlanFocusAllocations(
        for session: FocusSession,
        allocations: [DayPlanFocusTaskAllocation],
        tasks: [RoutineTask],
        now: Date = Date(),
        calendar: Calendar,
        context: ModelContext
    ) -> Bool {
        guard session.isUnassigned,
              session.abandonedAt == nil,
              let startedAt = session.startedAt else {
            return false
        }

        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        let availableMinutes = max(0, Int(floor(session.activeDurationSeconds(at: session.completedAt ?? now) / 60)))
        var remainingMinutes = availableMinutes
        let sanitizedAllocations = allocations
            .map { DayPlanFocusTaskAllocation(taskID: $0.taskID, minutes: max(0, $0.minutes)) }
            .filter { $0.minutes > 0 && tasksByID[$0.taskID] != nil }
            .compactMap { allocation -> DayPlanFocusTaskAllocation? in
                guard remainingMinutes > 0 else { return nil }
                let minutes = min(allocation.minutes, remainingMinutes)
                remainingMinutes -= minutes
                return DayPlanFocusTaskAllocation(taskID: allocation.taskID, minutes: minutes)
            }
        let existingBlocks = planFocusAllocationBlocks(for: session, context: context)
        let previousMinutesByTask = existingBlocks.reduce(into: [UUID: Int]()) { result, block in
            result[block.taskID, default: 0] += block.durationMinutes
        }
        let nextMinutesByTask = sanitizedAllocations.reduce(into: [UUID: Int]()) { result, allocation in
            result[allocation.taskID, default: 0] += allocation.minutes
        }

        do {
            for block in existingBlocks where nextMinutesByTask[block.taskID] == nil {
                deleteBlock(id: block.id, dayKey: block.dayKey, context: context)
            }

            var cursorMinutes = 0
            for allocation in sanitizedAllocations {
                guard let task = tasksByID[allocation.taskID] else { continue }
                let blockID = allocationBlockID(sessionID: session.id, taskID: allocation.taskID)
                let blockStart = calendar.date(byAdding: .minute, value: cursorMinutes, to: startedAt) ?? startedAt
                let startMinute = startMinute(
                    for: blockStart,
                    calendar: calendar,
                    minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
                )
                let block = DayPlanBlock(
                    id: blockID,
                    taskID: task.id,
                    dayKey: DayPlanStorage.dayKey(for: blockStart, calendar: calendar),
                    startMinute: startMinute,
                    durationMinutes: allocation.minutes,
                    titleSnapshot: DayPlanTaskSorting.title(for: task),
                    emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                    createdAt: startedAt,
                    updatedAt: now,
                    minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
                )
                upsertBlock(block, context: context)
                cursorMinutes += allocation.minutes
            }

            for task in tasks {
                let previousMinutes = previousMinutesByTask[task.id] ?? 0
                let nextMinutes = nextMinutesByTask[task.id] ?? 0
                let delta = nextMinutes - previousMinutes
                guard delta != 0 else { continue }
                let previousDuration = task.actualDurationMinutes
                let currentDuration = previousDuration ?? 0
                let updatedDuration = max(0, currentDuration + delta)
                task.actualDurationMinutes = updatedDuration > 0 ? updatedDuration : nil
                task.appendChangeLogEntry(timeSpentChangeEntry(
                    previousDurationMinutes: previousDuration,
                    durationMinutes: task.actualDurationMinutes
                ))
            }

            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
            return true
        } catch {
            NSLog("Failed to save plan focus allocations: \(error.localizedDescription)")
            return false
        }
    }

    static func hasPlanFocusAllocations(for session: FocusSession, context: ModelContext?) -> Bool {
        guard let context else { return false }
        return !planFocusAllocationBlocks(for: session, context: context).isEmpty
    }

    static func planFocusAllocatedMinutesBySessionID(
        for sessions: [FocusSession],
        context: ModelContext
    ) -> [UUID: Int] {
        let sessionIDs = sessions
            .filter(\.isUnassigned)
            .map(\.id)
        guard !sessionIDs.isEmpty else { return [:] }

        do {
            let records = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
            var result: [UUID: Int] = [:]

            for record in records {
                for sessionID in sessionIDs where record.id == allocationBlockID(
                    sessionID: sessionID,
                    taskID: record.taskID
                ) {
                    result[sessionID, default: 0] += record.durationMinutes
                    break
                }
            }

            return result
        } catch {
            NSLog("Failed to load plan focus allocation minutes: \(error.localizedDescription)")
            return [:]
        }
    }

    static func planFocusAllocationBlocks(for session: FocusSession, context: ModelContext) -> [DayPlanBlock] {
        do {
            let records = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
            return records
                .map(\.detachedBlock)
                .filter { block in
                    block.id == allocationBlockID(sessionID: session.id, taskID: block.taskID)
                }
                .sorted { lhs, rhs in
                    if lhs.dayKey != rhs.dayKey {
                        return lhs.dayKey < rhs.dayKey
                    }
                    return lhs.startMinute < rhs.startMinute
                }
        } catch {
            NSLog("Failed to load plan focus allocations: \(error.localizedDescription)")
            return []
        }
    }

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

    static func reconcileCountUpFocusSegments(
        for sessions: [FocusSession],
        tasks: [RoutineTask],
        calendar: Calendar,
        context: ModelContext
    ) {
        guard !sessions.isEmpty else { return }

        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        for session in sessions {
            guard session.plannedDurationSeconds <= 0,
                  session.abandonedAt == nil,
                  let startedAt = session.startedAt,
                  session.isTaskFocus || session.isTagFocus else {
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

            for segment in segments {
                let block = focusSegmentBlock(
                    session: session,
                    taskID: taskID,
                    title: title,
                    emoji: emoji,
                    segmentStartedAt: segment.startedAt,
                    durationSeconds: segment.durationSeconds,
                    calendar: calendar
                )
                upsertBlock(block, context: context)
            }
        }
    }

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

        if durationSeconds > 0,
           let existingBlock = blocks.first(where: { representsFocusBlock($0, focusBlock: block) }) {
            return existingBlock
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

        if durationSeconds > 0,
           let existingBlock = blocks.first(where: { representsFocusBlock($0, focusBlock: block) }) {
            return existingBlock
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
              let startedAt = session.startedAt else {
            return nil
        }

        let storedSegments = focusSegmentBlocks(for: session, context: context)
        if let segmentStartedAt = countUpSegmentStart(
            for: session,
            storedSegments: storedSegments,
            segmentEndedAt: endedAt,
            canInferCurrentSegment: session.accumulatedPausedSeconds > 0
        ),
           segmentStartedAt > startedAt {
            repairOvergrownCompletedSegments(
                for: session,
                storedSegments: storedSegments,
                currentSegmentStartedAt: segmentStartedAt,
                segmentEndedAt: endedAt,
                context: context
            )
            let durationSeconds = max(60, endedAt.timeIntervalSince(segmentStartedAt))
            let block = focusSegmentBlock(
                session: session,
                taskID: task.id,
                title: DayPlanTaskSorting.title(for: task),
                emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                segmentStartedAt: segmentStartedAt,
                durationSeconds: durationSeconds,
                calendar: calendar
            )
            upsertBlock(block, context: context)
            return block
        } else {
            let elapsedSeconds = max(60, session.activeDurationSeconds(at: endedAt))
            let block = plannerBlock(
                for: task,
                session: session,
                startedAt: startedAt,
                durationSeconds: elapsedSeconds,
                calendar: calendar,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            upsertBlock(block, context: context)
            return block
        }
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
              let startedAt = session.startedAt else {
            return nil
        }

        let storedSegments = focusSegmentBlocks(for: session, context: context)
        if let segmentStartedAt = countUpSegmentStart(
            for: session,
            storedSegments: storedSegments,
            segmentEndedAt: endedAt,
            canInferCurrentSegment: session.accumulatedPausedSeconds > 0
        ),
           segmentStartedAt > startedAt {
            repairOvergrownCompletedSegments(
                for: session,
                storedSegments: storedSegments,
                currentSegmentStartedAt: segmentStartedAt,
                segmentEndedAt: endedAt,
                context: context
            )
            let durationSeconds = max(60, endedAt.timeIntervalSince(segmentStartedAt))
            let title = RoutineTag.cleaned(tagName).map { "#\($0)" } ?? "#Tag"
            let block = focusSegmentBlock(
                session: session,
                taskID: FocusSession.unassignedTaskID,
                title: title,
                emoji: nil,
                segmentStartedAt: segmentStartedAt,
                durationSeconds: durationSeconds,
                calendar: calendar
            )
            upsertBlock(block, context: context)
            return block
        } else {
            let elapsedSeconds = max(60, session.activeDurationSeconds(at: endedAt))
            let block = tagPlannerBlock(
                tagName: tagName,
                session: session,
                startedAt: startedAt,
                durationSeconds: elapsedSeconds,
                calendar: calendar,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            upsertBlock(block, context: context)
            return block
        }
    }

    @discardableResult
    static func saveCompletedFocusBlock(
        for task: RoutineTask,
        session: FocusSession,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard let startedAt = session.startedAt,
              let endedAt = session.completedAt else {
            return nil
        }

        let elapsedSeconds = max(60, session.activeDurationSeconds(at: endedAt))
        let block = plannerBlock(
            for: task,
            session: session,
            startedAt: startedAt,
            durationSeconds: elapsedSeconds,
            calendar: calendar,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        var blocks = DayPlanStorage.loadBlocks(forDayKey: block.dayKey, context: context)

        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
        } else {
            blocks.append(block)
        }

        DayPlanStorage.saveBlocks(blocks, forDayKey: block.dayKey, context: context)
        return block
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
        let minimumDurationMinutes = minimumDurationMinutes
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

    private static func focusSegmentBlocks(for session: FocusSession, context: ModelContext) -> [DayPlanBlock] {
        do {
            let records = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
            return focusSegmentBlocks(in: records.map(\.detachedBlock), for: session)
        } catch {
            NSLog("Failed to load focus planner segments for \(session.id): \(error.localizedDescription)")
            return []
        }
    }

    private struct FocusPauseResumeAction {
        var kind: RoutinaDeviceActionKind
        var timestamp: Date
    }

    private struct FocusSegmentInterval {
        var startedAt: Date
        var endedAt: Date?

        var durationSeconds: TimeInterval {
            guard let endedAt else {
                return 60
            }

            return max(60, endedAt.timeIntervalSince(startedAt))
        }
    }

    private static func focusPauseResumeActionLogs(
        for sessionID: UUID,
        context: ModelContext
    ) -> [FocusPauseResumeAction] {
        let sessionIDString = sessionID.uuidString
        let focusEntity = RoutinaDeviceActionEntity.focusSession.rawValue
        let pausedAction = RoutinaDeviceActionKind.paused.rawValue
        let resumedAction = RoutinaDeviceActionKind.resumed.rawValue
        var descriptor = FetchDescriptor<RoutinaDeviceActionLog>(
            predicate: #Predicate<RoutinaDeviceActionLog> { log in
                log.entityRawValue == focusEntity
                    && log.entityID == sessionIDString
                    && (log.actionRawValue == pausedAction || log.actionRawValue == resumedAction)
            }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]

        do {
            return try context.fetch(descriptor).compactMap { log in
                guard let kind = RoutinaDeviceActionKind(rawValue: log.actionRawValue) else {
                    return nil
                }

                return FocusPauseResumeAction(kind: kind, timestamp: log.timestamp)
            }
        } catch {
            NSLog("Failed to load focus pause/resume action logs for \(sessionID): \(error.localizedDescription)")
            return []
        }
    }

    private static func focusSegments(
        startedAt: Date,
        completedAt: Date?,
        pausedAt: Date?,
        actions: [FocusPauseResumeAction]
    ) -> [FocusSegmentInterval] {
        var segments: [FocusSegmentInterval] = []
        var currentStart: Date? = startedAt

        for action in actions where action.timestamp >= startedAt {
            switch action.kind {
            case .paused:
                guard let segmentStart = currentStart,
                      action.timestamp > segmentStart else {
                    continue
                }

                segments.append(FocusSegmentInterval(startedAt: segmentStart, endedAt: action.timestamp))
                currentStart = nil

            case .resumed:
                guard currentStart == nil else {
                    continue
                }

                currentStart = action.timestamp

            default:
                continue
            }
        }

        if let completedAt,
           let segmentStart = currentStart,
           completedAt > segmentStart {
            segments.append(FocusSegmentInterval(startedAt: segmentStart, endedAt: completedAt))
        } else if let pausedAt,
                  let segmentStart = currentStart,
                  pausedAt > segmentStart {
            segments.append(FocusSegmentInterval(startedAt: segmentStart, endedAt: pausedAt))
        } else if let segmentStart = currentStart,
                  segmentStart > startedAt {
            segments.append(FocusSegmentInterval(startedAt: segmentStart, endedAt: nil))
        }

        return segments
    }

    private static func countUpSegmentStart(
        for session: FocusSession,
        storedSegments: [DayPlanBlock],
        segmentEndedAt: Date,
        canInferCurrentSegment: Bool
    ) -> Date? {
        guard let startedAt = session.startedAt else {
            return nil
        }

        if canInferCurrentSegment,
           session.accumulatedPausedSeconds > 0,
           let inferredStart = inferredUnsavedCurrentSegmentStart(
                for: session,
                storedSegments: storedSegments,
                segmentEndedAt: segmentEndedAt
           ) {
            if let latestSegment = storedSegments.last {
                let latestSegmentEnd = latestSegment.createdAt.addingTimeInterval(
                    storedSegmentDurationSeconds(latestSegment)
                )
                if inferredStart > latestSegmentEnd {
                    return inferredStart
                }
            } else if inferredStart > startedAt {
                return inferredStart
            }
        }

        if let latestSegment = storedSegments.last,
           latestSegment.createdAt > startedAt,
           isCurrentSegmentPlaceholder(latestSegment, for: session) {
            return latestSegment.createdAt
        }

        if let latestSegment = storedSegments.last {
            if latestSegment.id == session.id,
               latestSegment.durationMinutes <= DayPlanBlock.minimumStoredDurationMinutes {
                return startedAt
            }

            if latestSegment.createdAt > startedAt {
                return latestSegment.createdAt
            }

            if canInferCurrentSegment,
               session.accumulatedPausedSeconds > 0 {
                return nil
            }
        }

        return startedAt
    }

    private static func inferredUnsavedCurrentSegmentStart(
        for session: FocusSession,
        storedSegments: [DayPlanBlock],
        segmentEndedAt: Date
    ) -> Date? {
        guard let startedAt = session.startedAt else {
            return nil
        }

        let activeSeconds = session.activeDurationSeconds(at: segmentEndedAt)
        let storedSeconds = storedSegments
            .filter { $0.createdAt < segmentEndedAt }
            .reduce(TimeInterval.zero) { total, segment in
                total + storedSegmentDurationSeconds(segment)
            }
        guard storedSeconds > TimeInterval(DayPlanBlock.minimumStoredDurationMinutes * 60) else {
            return nil
        }

        let currentSegmentSeconds = activeSeconds - storedSeconds
        guard currentSegmentSeconds > 0 else {
            return nil
        }

        let inferredStart = segmentEndedAt.addingTimeInterval(-currentSegmentSeconds)
        guard inferredStart > startedAt else {
            return nil
        }

        return inferredStart
    }

    private static func isCurrentSegmentPlaceholder(_ segment: DayPlanBlock, for session: FocusSession) -> Bool {
        segment.id != session.id
            && segment.durationMinutes <= DayPlanBlock.minimumStoredDurationMinutes
    }

    private static func storedSegmentDurationSeconds(_ segment: DayPlanBlock) -> TimeInterval {
        let storedMinutesSeconds = TimeInterval(max(DayPlanBlock.minimumStoredDurationMinutes, segment.durationMinutes) * 60)
        let timestampSeconds = segment.updatedAt.timeIntervalSince(segment.createdAt)
        guard timestampSeconds > 0, timestampSeconds <= storedMinutesSeconds else {
            return storedMinutesSeconds
        }

        return timestampSeconds
    }

    private static func repairOvergrownCompletedSegments(
        for session: FocusSession,
        storedSegments: [DayPlanBlock],
        currentSegmentStartedAt: Date,
        segmentEndedAt: Date,
        context: ModelContext
    ) {
        guard session.accumulatedPausedSeconds > 0 else {
            return
        }

        let completedSegments = storedSegments.filter { $0.createdAt < currentSegmentStartedAt }
        guard !completedSegments.isEmpty else {
            return
        }

        let activeSeconds = session.activeDurationSeconds(at: segmentEndedAt)
        let currentSegmentSeconds = max(0, segmentEndedAt.timeIntervalSince(currentSegmentStartedAt))
        let completedBudgetSeconds = max(0, activeSeconds - currentSegmentSeconds)
        let corrections = completedSegmentDurationCorrections(
            completedSegments,
            budgetSeconds: completedBudgetSeconds
        )
        guard !corrections.isEmpty else {
            return
        }

        for segment in completedSegments {
            guard let durationMinutes = corrections[segment.id] else {
                continue
            }

            upsertBlock(copyBlock(segment, durationMinutes: durationMinutes), context: context)
        }
    }

    private static func savePausedCountUpFocusSegment(
        session: FocusSession,
        taskID: UUID,
        title: String,
        emoji: String?,
        pausedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard session.plannedDurationSeconds <= 0,
              session.startedAt != nil else {
            return nil
        }

        let storedSegments = focusSegmentBlocks(for: session, context: context)
        guard let segmentStartedAt = countUpSegmentStart(
            for: session,
            storedSegments: storedSegments,
            segmentEndedAt: pausedAt,
            canInferCurrentSegment: true
        ) else {
            return nil
        }
        guard pausedAt >= segmentStartedAt else {
            return nil
        }

        repairOvergrownCompletedSegments(
            for: session,
            storedSegments: storedSegments,
            currentSegmentStartedAt: segmentStartedAt,
            segmentEndedAt: pausedAt,
            context: context
        )
        let block = focusSegmentBlock(
            session: session,
            taskID: taskID,
            title: title,
            emoji: emoji,
            segmentStartedAt: segmentStartedAt,
            durationSeconds: max(60, pausedAt.timeIntervalSince(segmentStartedAt)),
            calendar: calendar
        )
        upsertBlock(block, context: context)
        return block
    }

    private static func saveResumedCountUpFocusSegment(
        session: FocusSession,
        taskID: UUID,
        title: String,
        emoji: String?,
        resumedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard session.plannedDurationSeconds <= 0,
              let startedAt = session.startedAt,
              resumedAt >= startedAt else {
            return nil
        }

        let block = focusSegmentBlock(
            session: session,
            taskID: taskID,
            title: title,
            emoji: emoji,
            segmentStartedAt: resumedAt,
            durationSeconds: 60,
            calendar: calendar
        )
        upsertBlock(block, context: context)
        return block
    }

    private static func latestFocusSegmentBlock(for session: FocusSession, context: ModelContext) -> DayPlanBlock? {
        focusSegmentBlocks(for: session, context: context).last
    }

    private static func focusSegmentBlock(
        session: FocusSession,
        taskID: UUID,
        title: String,
        emoji: String?,
        segmentStartedAt: Date,
        durationSeconds: TimeInterval,
        calendar: Calendar
    ) -> DayPlanBlock {
        let startMinute = startMinute(
            for: segmentStartedAt,
            calendar: calendar,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        return DayPlanBlock(
            id: segmentBlockID(
                sessionID: session.id,
                sessionStartedAt: session.startedAt,
                segmentStartedAt: segmentStartedAt
            ),
            taskID: taskID,
            dayKey: DayPlanStorage.dayKey(for: segmentStartedAt, calendar: calendar),
            startMinute: startMinute,
            durationMinutes: durationMinutes(
                durationSeconds: durationSeconds,
                startMinute: startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            ),
            titleSnapshot: title,
            emojiSnapshot: emoji,
            createdAt: segmentStartedAt,
            updatedAt: segmentStartedAt.addingTimeInterval(max(0, durationSeconds)),
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
    }

    private static func segmentBlockID(
        sessionID: UUID,
        sessionStartedAt: Date?,
        segmentStartedAt: Date
    ) -> UUID {
        if let sessionStartedAt,
           sessionStartedAt == segmentStartedAt {
            return sessionID
        }

        return focusSegmentBlockID(sessionID: sessionID, segmentStartedAt: segmentStartedAt)
    }

    static func focusSegmentBlockID(sessionID: UUID, segmentStartedAt: Date) -> UUID {
        let sessionBytes = sessionID.uuid
        let milliseconds = Int64((segmentStartedAt.timeIntervalSince1970 * 1_000).rounded())
        let timestampBytes = UInt64(bitPattern: milliseconds)

        func timestampByte(_ shift: UInt64) -> UInt8 {
            UInt8((timestampBytes >> shift) & 0xff)
        }

        let b0 = timestampByte(56)
        let b1 = timestampByte(48)
        let b2 = timestampByte(40)
        let b3 = timestampByte(32)
        let b4 = timestampByte(24)
        let b5 = timestampByte(16)
        let b6 = timestampByte(8)
        let b7 = timestampByte(0)

        return UUID(uuid: (
            sessionBytes.0 ^ b0,
            sessionBytes.1 ^ b1,
            sessionBytes.2 ^ b2,
            sessionBytes.3 ^ b3,
            sessionBytes.4 ^ b4,
            sessionBytes.5 ^ b5,
            sessionBytes.6 ^ b6,
            sessionBytes.7 ^ b7,
            sessionBytes.8 ^ b7,
            sessionBytes.9 ^ b6,
            sessionBytes.10 ^ b5,
            sessionBytes.11 ^ b4,
            sessionBytes.12 ^ b3,
            sessionBytes.13 ^ b2,
            sessionBytes.14 ^ b1,
            sessionBytes.15 ^ b0
        ))
    }

    static func tagPlannerBlock(
        tagName: String,
        session: FocusSession,
        startedAt: Date,
        durationSeconds: TimeInterval,
        calendar: Calendar,
        minimumDurationMinutes: Int? = nil
    ) -> DayPlanBlock {
        let minimumDurationMinutes = minimumDurationMinutes
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

    private static func startMinute(
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

    private static func durationMinutes(
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

    private static func representsFocusBlock(
        _ plannedBlock: DayPlanBlock,
        focusBlock: DayPlanBlock
    ) -> Bool {
        if plannedBlock.id == focusBlock.id {
            return true
        }

        guard plannedBlock.taskID == focusBlock.taskID,
              plannedBlock.dayKey == focusBlock.dayKey else {
            return false
        }

        return plannedBlock.startMinute < focusBlock.endMinute
            && focusBlock.startMinute < plannedBlock.endMinute
    }

    private static func upsertBlock(_ block: DayPlanBlock, context: ModelContext) {
        var blocks = DayPlanStorage.loadBlocks(forDayKey: block.dayKey, context: context)
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
        } else {
            blocks.append(block)
        }
        DayPlanStorage.saveBlocks(blocks, forDayKey: block.dayKey, context: context)
    }

    private static func deleteBlock(id: UUID, dayKey: String, context: ModelContext) {
        var blocks = DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
        blocks.removeAll { $0.id == id }
        DayPlanStorage.saveBlocks(blocks, forDayKey: dayKey, context: context)
    }

    private static func timeSpentChangeEntry(
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

enum DayPlanSprintFocusBlocks {
    private struct VisibleDayWindow {
        let dayKey: String
        let start: Date
        let end: Date
    }

    static func blocksByDayKey(
        on dates: [Date],
        from sessions: [SprintFocusSessionRecord],
        allocations: [SprintFocusAllocationRecord],
        sprints: [BoardSprintRecord],
        tasks: [RoutineTask],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [String: [DayPlanSprintFocusBlock]] {
        let visibleDates = dates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        guard !visibleDates.isEmpty else { return [:] }
        let visibleDayWindows = visibleDates.compactMap { dayStart -> VisibleDayWindow? in
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return nil
            }

            return VisibleDayWindow(
                dayKey: DayPlanStorage.dayKey(for: dayStart, calendar: calendar),
                start: dayStart,
                end: dayEnd
            )
        }
        guard let visibleRangeStart = visibleDayWindows.first?.start,
              let visibleRangeEnd = visibleDayWindows.last?.end else {
            return [:]
        }
        let relevantSessions = sessions.filter {
            sessionOverlapsVisibleRange(
                $0,
                visibleRangeStart: visibleRangeStart,
                visibleRangeEnd: visibleRangeEnd,
                referenceDate: referenceDate
            )
        }
        guard !relevantSessions.isEmpty else { return [:] }

        let relevantSessionIDs = Set(relevantSessions.map(\.id))
        let allocationsBySessionID = Dictionary(
            grouping: allocations.filter { relevantSessionIDs.contains($0.sessionID) },
            by: \.sessionID
        )
        var sprintsByID: [UUID: BoardSprintRecord] = [:]
        for sprint in sprints where sprintsByID[sprint.id] == nil {
            sprintsByID[sprint.id] = sprint
        }
        var tasksByID: [UUID: RoutineTask] = [:]
        for task in tasks where tasksByID[task.id] == nil {
            tasksByID[task.id] = task
        }
        let blocks = relevantSessions.flatMap { session in
            blocksForSession(
                session,
                allocations: allocationsBySessionID[session.id] ?? [],
                sprint: sprintsByID[session.sprintID],
                tasksByID: tasksByID,
                visibleDayWindows: visibleDayWindows,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }

        return Dictionary(grouping: blocks, by: \.block.dayKey)
            .mapValues {
                $0.sorted { lhs, rhs in
                    if lhs.block.startMinute != rhs.block.startMinute {
                        return lhs.block.startMinute < rhs.block.startMinute
                    }
                    if lhs.isAllocatedToTask != rhs.isAllocatedToTask {
                        return lhs.isAllocatedToTask && !rhs.isAllocatedToTask
                    }
                    return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
                }
            }
    }

    static func blockedIntervalsByDayKey(
        on dates: [Date],
        from sessions: [SprintFocusSessionRecord],
        allocations: [SprintFocusAllocationRecord],
        sprints: [BoardSprintRecord],
        tasks: [RoutineTask],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [String: [DayPlanBlockedInterval]] {
        blocksByDayKey(
            on: dates,
            from: sessions,
            allocations: allocations,
            sprints: sprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .mapValues { blocks in
            blocks.map(\.interval)
        }
    }

    private static func sessionOverlapsVisibleRange(
        _ session: SprintFocusSessionRecord,
        visibleRangeStart: Date,
        visibleRangeEnd: Date,
        referenceDate: Date
    ) -> Bool {
        let sessionEnd = max(session.stoppedAt ?? referenceDate, session.startedAt)
        return session.startedAt < visibleRangeEnd && sessionEnd >= visibleRangeStart
    }

    private static func blocksForSession(
        _ session: SprintFocusSessionRecord,
        allocations: [SprintFocusAllocationRecord],
        sprint: BoardSprintRecord?,
        tasksByID: [UUID: RoutineTask],
        visibleDayWindows: [VisibleDayWindow],
        referenceDate: Date,
        calendar: Calendar
    ) -> [DayPlanSprintFocusBlock] {
        let totalMinutes = recordedMinutes(for: session, referenceDate: referenceDate)
        guard totalMinutes > 0 else { return [] }

        var cursorMinutes = 0
        var blocks: [DayPlanSprintFocusBlock] = []
        let sortedAllocations = allocations
            .filter { $0.minutes > 0 }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.taskID.uuidString < rhs.taskID.uuidString
            }

        for allocation in sortedAllocations where cursorMinutes < totalMinutes {
            let minutes = min(max(0, allocation.minutes), totalMinutes - cursorMinutes)
            guard minutes > 0 else { continue }

            let task = tasksByID[allocation.taskID]
            let title = task.map(DayPlanTaskSorting.title) ?? "Allocated focus"
            let emoji = task.flatMap { CalendarTaskImportSupport.displayEmoji(for: $0.emoji) }
            blocks.append(contentsOf: segmentBlocks(
                id: allocation.id,
                sessionID: session.id,
                taskID: allocation.taskID,
                title: title,
                emoji: emoji,
                startedAt: session.startedAt,
                offsetMinutes: cursorMinutes,
                durationMinutes: minutes,
                visibleDayWindows: visibleDayWindows,
                updatedAt: session.stoppedAt ?? referenceDate,
                isActive: session.isActive,
                isAllocatedToTask: true,
                calendar: calendar
            ))
            cursorMinutes += minutes
        }

        let remainingMinutes = totalMinutes - cursorMinutes
        if remainingMinutes > 0 {
            blocks.append(contentsOf: segmentBlocks(
                id: session.id,
                sessionID: session.id,
                taskID: session.sprintID,
                title: sprintTitle(sprint),
                emoji: "🏁",
                startedAt: session.startedAt,
                offsetMinutes: cursorMinutes,
                durationMinutes: remainingMinutes,
                visibleDayWindows: visibleDayWindows,
                updatedAt: session.stoppedAt ?? referenceDate,
                isActive: session.isActive,
                isAllocatedToTask: false,
                calendar: calendar
            ))
        }

        return blocks
    }

    private static func segmentBlocks(
        id: UUID,
        sessionID: UUID,
        taskID: UUID,
        title: String,
        emoji: String?,
        startedAt: Date,
        offsetMinutes: Int,
        durationMinutes: Int,
        visibleDayWindows: [VisibleDayWindow],
        updatedAt: Date,
        isActive: Bool,
        isAllocatedToTask: Bool,
        calendar: Calendar
    ) -> [DayPlanSprintFocusBlock] {
        guard let segmentStart = calendar.date(byAdding: .minute, value: offsetMinutes, to: startedAt),
              let segmentEnd = calendar.date(byAdding: .minute, value: durationMinutes, to: segmentStart),
              segmentEnd > segmentStart else {
            return []
        }

        return visibleDayWindows.compactMap { day -> DayPlanSprintFocusBlock? in
            let intervalStart = max(segmentStart, day.start)
            let intervalEnd = min(segmentEnd, day.end)
            guard intervalEnd > intervalStart else { return nil }

            let startMinute = Self.startMinute(for: intervalStart, calendar: calendar)
            let rawDuration = max(1, Int(ceil(intervalEnd.timeIntervalSince(intervalStart) / 60)))
            let durationMinutes = DayPlanBlock.clampedDuration(
                rawDuration,
                startMinute: startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            let block = DayPlanBlock(
                id: id,
                taskID: taskID,
                dayKey: day.dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: title,
                emojiSnapshot: emoji,
                createdAt: startedAt,
                updatedAt: updatedAt,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            let interval = DayPlanBlockedInterval(
                dayKey: day.dayKey,
                startMinute: block.startMinute,
                endMinute: block.endMinute,
                title: title
            )

            return DayPlanSprintFocusBlock(
                sessionID: sessionID,
                block: block,
                interval: interval,
                isActive: isActive,
                isAllocatedToTask: isAllocatedToTask
            )
        }
    }

    private static func recordedMinutes(
        for session: SprintFocusSessionRecord,
        referenceDate: Date
    ) -> Int {
        max(1, Int(floor(session.activeDurationSeconds(at: referenceDate) / 60)))
    }

    private static func sprintTitle(_ sprint: BoardSprintRecord?) -> String {
        let title = sprint?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "Board focus" : title
    }

    private static func startMinute(for timestamp: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(
            minute,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
    }
}
