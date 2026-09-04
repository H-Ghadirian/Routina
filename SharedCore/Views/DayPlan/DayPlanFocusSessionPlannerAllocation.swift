import Foundation
import SwiftData

extension DayPlanFocusSessionPlannerSync {
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
            let startedAt = session.startedAt
        else {
            return false
        }

        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        let availableMinutes = max(0, Int(floor(session.activeDurationSeconds(at: session.completedAt ?? now) / 60)))
        var remainingMinutes = availableMinutes
        let sanitizedAllocations =
            allocations
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
                task.appendChangeLogEntry(
                    timeSpentChangeEntry(
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
        let sessionIDs =
            sessions
            .filter(\.isUnassigned)
            .map(\.id)
        guard !sessionIDs.isEmpty else { return [:] }

        do {
            let records = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
            var result: [UUID: Int] = [:]

            for record in records {
                for sessionID in sessionIDs {
                    guard
                        record.id
                            == allocationBlockID(
                                sessionID: sessionID,
                                taskID: record.taskID
                            )
                    else {
                        continue
                    }

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
            return
                records
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
}
