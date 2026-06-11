import Foundation
import SwiftData

struct DayPlanFocusSessionBlock: Identifiable, Equatable {
    var sessionID: UUID
    var block: DayPlanBlock
    var durationMinutes: Int
    var opensTaskDetails: Bool = true

    var id: String {
        "\(block.dayKey)-\(sessionID.uuidString)"
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
        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        let blocks = sessions.compactMap { session -> DayPlanFocusSessionBlock? in
            if session.isUnassigned {
                return planFocusBlock(for: session, now: now, calendar: calendar)
            }

            guard session.completedAt == nil,
                  session.abandonedAt == nil,
                  let startedAt = session.startedAt,
                  let task = tasksByID[session.taskID]
            else { return nil }

            let dayKey = DayPlanStorage.dayKey(for: now, calendar: calendar)
            let renderStart = renderStart(for: startedAt, now: now, calendar: calendar)
            let startMinute = startMinute(for: renderStart, calendar: calendar)
            let elapsedSeconds = max(
                60,
                elapsedFocusSeconds(for: session, startedAt: startedAt, renderStart: renderStart, now: now)
            )
            let elapsedMinutes = max(1, Int(ceil(elapsedSeconds / 60)))
            let remainingMinutes = max(1, DayPlanBlock.minutesPerDay - startMinute)
            let durationMinutes = min(elapsedMinutes, remainingMinutes)
            let block = DayPlanBlock(
                id: session.id,
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

        return blocks.sorted { lhs, rhs in
            if lhs.block.startMinute != rhs.block.startMinute {
                return lhs.block.startMinute < rhs.block.startMinute
            }
            return lhs.block.titleSnapshot.localizedCaseInsensitiveCompare(rhs.block.titleSnapshot) == .orderedAscending
        }
    }

    private static func planFocusBlock(
        for session: FocusSession,
        now: Date,
        calendar: Calendar
    ) -> DayPlanFocusSessionBlock? {
        guard session.abandonedAt == nil,
              let startedAt = session.startedAt,
              calendar.isDate(startedAt, inSameDayAs: now) else {
            return nil
        }

        let renderEnd = session.finishedAt ?? now
        guard renderEnd >= startedAt else { return nil }

        let dayKey = DayPlanStorage.dayKey(for: startedAt, calendar: calendar)
        let startMinute = startMinute(for: startedAt, calendar: calendar)
        let elapsedSeconds = max(60, session.activeDurationSeconds(at: renderEnd))
        let elapsedMinutes = max(1, Int(ceil(elapsedSeconds / 60)))
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
            createdAt: startedAt,
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
            return max(0, now.timeIntervalSince(renderStart))
        }

        return session.activeDurationSeconds(at: now)
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
            let sessionID = session.id
            let descriptor = FetchDescriptor<DayPlanBlockRecord>(
                predicate: #Predicate<DayPlanBlockRecord> { record in
                    record.id == sessionID
                }
            )
            let records = try context.fetch(descriptor)
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
    static func blocksByDayKey(
        on dates: [Date],
        from sessions: [SprintFocusSessionRecord],
        allocations: [SprintFocusAllocationRecord],
        sprints: [BoardSprintRecord],
        tasks: [RoutineTask],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [String: [DayPlanSprintFocusBlock]] {
        let visibleDates = dates.map { calendar.startOfDay(for: $0) }
        guard !visibleDates.isEmpty else { return [:] }

        let allocationsBySessionID = Dictionary(grouping: allocations, by: \.sessionID)
        let sprintsByID = Dictionary(grouping: sprints, by: \.id).compactMapValues(\.first)
        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        let blocks = sessions.flatMap { session in
            blocksForSession(
                session,
                allocations: allocationsBySessionID[session.id] ?? [],
                sprint: sprintsByID[session.sprintID],
                tasksByID: tasksByID,
                visibleDates: visibleDates,
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

    private static func blocksForSession(
        _ session: SprintFocusSessionRecord,
        allocations: [SprintFocusAllocationRecord],
        sprint: BoardSprintRecord?,
        tasksByID: [UUID: RoutineTask],
        visibleDates: [Date],
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
                visibleDates: visibleDates,
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
                visibleDates: visibleDates,
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
        visibleDates: [Date],
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

        return visibleDates.compactMap { visibleDate -> DayPlanSprintFocusBlock? in
            let dayStart = calendar.startOfDay(for: visibleDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return nil
            }

            let intervalStart = max(segmentStart, dayStart)
            let intervalEnd = min(segmentEnd, dayEnd)
            guard intervalEnd > intervalStart else { return nil }

            let dayKey = DayPlanStorage.dayKey(for: dayStart, calendar: calendar)
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
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: title,
                emojiSnapshot: emoji,
                createdAt: startedAt,
                updatedAt: updatedAt,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            let interval = DayPlanBlockedInterval(
                dayKey: dayKey,
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
