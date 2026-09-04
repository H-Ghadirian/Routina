import Foundation

enum DayPlanSprintFocusBlocks {
    private struct VisibleDayWindow {
        let dayKey: String
        let start: Date
        let end: Date
    }

    private struct SegmentInput {
        let id: UUID
        let sessionID: UUID
        let taskID: UUID
        let title: String
        let emoji: String?
        let startedAt: Date
        let offsetMinutes: Int
        let durationMinutes: Int
        let visibleDayWindows: [VisibleDayWindow]
        let updatedAt: Date
        let isActive: Bool
        let isAllocatedToTask: Bool
        let calendar: Calendar
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
        let visibleDates =
            dates
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
            let visibleRangeEnd = visibleDayWindows.last?.end
        else {
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
        let sortedAllocations =
            allocations
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
            blocks.append(
                contentsOf: segmentBlocks(
                    SegmentInput(
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
                    )
                ))
            cursorMinutes += minutes
        }

        let remainingMinutes = totalMinutes - cursorMinutes
        if remainingMinutes > 0 {
            blocks.append(
                contentsOf: segmentBlocks(
                    SegmentInput(
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
                    )
                ))
        }

        return blocks
    }

    private static func segmentBlocks(_ input: SegmentInput) -> [DayPlanSprintFocusBlock] {
        guard
            let segmentStart = input.calendar.date(
                byAdding: .minute,
                value: input.offsetMinutes,
                to: input.startedAt
            ),
            let segmentEnd = input.calendar.date(
                byAdding: .minute,
                value: input.durationMinutes,
                to: segmentStart
            ),
            segmentEnd > segmentStart
        else {
            return []
        }

        return input.visibleDayWindows.compactMap { day -> DayPlanSprintFocusBlock? in
            let intervalStart = max(segmentStart, day.start)
            let intervalEnd = min(segmentEnd, day.end)
            guard intervalEnd > intervalStart else { return nil }

            let startMinute = Self.startMinute(for: intervalStart, calendar: input.calendar)
            let rawDuration = max(1, Int(ceil(intervalEnd.timeIntervalSince(intervalStart) / 60)))
            let durationMinutes = DayPlanBlock.clampedDuration(
                rawDuration,
                startMinute: startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            let block = DayPlanBlock(
                id: input.id,
                taskID: input.taskID,
                dayKey: day.dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: input.title,
                emojiSnapshot: input.emoji,
                createdAt: input.startedAt,
                updatedAt: input.updatedAt,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            let interval = DayPlanBlockedInterval(
                dayKey: day.dayKey,
                startMinute: block.startMinute,
                endMinute: block.endMinute,
                title: input.title
            )

            return DayPlanSprintFocusBlock(
                sessionID: input.sessionID,
                block: block,
                interval: interval,
                isActive: input.isActive,
                isAllocatedToTask: input.isAllocatedToTask
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
