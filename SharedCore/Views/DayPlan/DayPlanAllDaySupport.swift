import Foundation

struct DayPlanEventBlock: Identifiable, Equatable {
    var eventID: UUID
    var block: DayPlanBlock

    var id: String {
        "event-\(eventID.uuidString)-\(block.dayKey)"
    }
}

struct DayPlanAllDayBlock: Identifiable, Equatable {
    var id: UUID
    var taskID: UUID?
    var eventID: UUID?
    var title: String
    var emoji: String?
    var startDate: Date
    var endDate: Date
    var isLegacyDateOnlyCalendarTask: Bool
    var isEvent: Bool
}

enum DayPlanAllDayTasks {
    private typealias AllDaySpan = (startDate: Date, endDate: Date, isLegacyDateOnlyCalendarTask: Bool)

    static func blocks(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog] = [],
        events: [RoutineEvent] = [],
        calendar: Calendar
    ) -> [DayPlanAllDayBlock] {
        guard let firstDate = dates.first,
              let lastDate = dates.last,
              let visibleEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: lastDate)
              )
        else { return [] }

        let visibleStart = calendar.startOfDay(for: firstDate)
        let logsByTaskID = Dictionary(grouping: logs, by: \.taskID)

        let taskBlocks = tasks.flatMap { task -> [DayPlanAllDayBlock] in
            guard !task.isCanceledOneOff,
                  !task.isArchived(referenceDate: visibleStart, calendar: calendar) else {
                return []
            }

            return allDaySpans(
                for: task,
                on: dates,
                logs: logsByTaskID[task.id] ?? [],
                calendar: calendar
            )
                .filter { span in
                    span.endDate > visibleStart && span.startDate < visibleEnd
                }
                .map { span in
                    DayPlanAllDayBlock(
                        id: task.id,
                        taskID: task.id,
                        eventID: nil,
                        title: DayPlanTaskSorting.title(for: task),
                        emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                        startDate: span.startDate,
                        endDate: span.endDate,
                        isLegacyDateOnlyCalendarTask: span.isLegacyDateOnlyCalendarTask,
                        isEvent: false
                    )
                }
        }

        let eventBlocks = events.compactMap { event -> DayPlanAllDayBlock? in
            guard event.isAllDay,
                  let startedAt = event.startedAt else {
                return nil
            }

            let startDate = calendar.startOfDay(for: startedAt)
            let endDate = normalizedEndDate(
                startDate: startedAt,
                endDate: event.endedAt ?? startedAt,
                calendar: calendar
            )
            guard endDate > visibleStart, startDate < visibleEnd else { return nil }

            return DayPlanAllDayBlock(
                id: event.id,
                taskID: nil,
                eventID: event.id,
                title: event.displayTitle,
                emoji: event.displayEmoji,
                startDate: startDate,
                endDate: endDate,
                isLegacyDateOnlyCalendarTask: false,
                isEvent: true
            )
        }

        return (taskBlocks + eventBlocks)
        .sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }
            if lhs.endDate != rhs.endDate {
                return lhs.endDate > rhs.endDate
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func allDaySpans(
        for task: RoutineTask,
        on dates: [Date],
        logs: [RoutineLog],
        calendar: Calendar
    ) -> [AllDaySpan] {
        if let metadata = CalendarTaskImportSupport.eventMetadata(in: task.notes),
           metadata.isAllDay {
            let startDate = calendar.startOfDay(for: metadata.startDate)
            let endDate = normalizedEndDate(
                startDate: metadata.startDate,
                endDate: metadata.endDate,
                calendar: calendar
            )
            guard endDate > startDate else { return [] }
            return [(startDate, endDate, false)]
        }

        if task.isAllDay {
            var spans: [AllDaySpan] = []
            if task.isOneOffTask {
                if task.availabilityStartDate != nil {
                    spans += availabilityDateStarts(for: task, on: dates, calendar: calendar)
                        .compactMap { startDate in
                            oneDaySpan(on: startDate, calendar: calendar)
                        }
                } else if let deadline = task.deadline,
                          let span = oneDaySpan(on: deadline, calendar: calendar) {
                    spans.append(span)
                }
            } else {
                let spanDays = RoutineTask.sanitizedAllDaySpanDays(task.allDaySpanDays)
                spans += routineAllDayOccurrenceStarts(
                    for: task,
                    on: dates,
                    spanDays: spanDays,
                    calendar: calendar
                )
                    .compactMap { startDate in
                        routineAllDaySpan(on: startDate, spanDays: spanDays, calendar: calendar)
                    }
            }

            spans += completedActivityStarts(for: task, logs: logs, on: dates, calendar: calendar)
                .compactMap { startDate in
                    oneDaySpan(on: startDate, calendar: calendar)
                }

            return deduplicatedAllDaySpans(spans, calendar: calendar)
        }

        guard task.isOneOffTask,
              let notes = task.notes,
              CalendarTaskImportSupport.sourceMarker(in: notes) != nil,
              let deadline = task.deadline,
              !hasExplicitTime(deadline, calendar: calendar) else {
            return []
        }

        guard let span = oneDaySpan(on: deadline, calendar: calendar) else { return [] }
        return [(span.startDate, span.endDate, true)]
    }

    private static func oneDaySpan(
        on date: Date,
        calendar: Calendar
    ) -> AllDaySpan? {
        let startDate = calendar.startOfDay(for: date)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate),
              endDate > startDate else {
            return nil
        }
        return (startDate, endDate, false)
    }

    private static func routineAllDaySpan(
        on date: Date,
        spanDays: Int,
        calendar: Calendar
    ) -> AllDaySpan? {
        let startDate = calendar.startOfDay(for: date)
        guard let endDate = calendar.date(
            byAdding: .day,
            value: RoutineTask.sanitizedAllDaySpanDays(spanDays),
            to: startDate
        ),
              endDate > startDate else {
            return nil
        }
        return (startDate, endDate, false)
    }

    private static func availabilityDateStarts(
        for task: RoutineTask,
        on dates: [Date],
        calendar: Calendar
    ) -> [Date] {
        guard let availabilityStartDate = task.availabilityStartDate else { return [] }
        let startDay = calendar.startOfDay(for: availabilityStartDate)
        let endDay = calendar.startOfDay(for: task.availabilityEndDate ?? availabilityStartDate)

        return dates
            .map { calendar.startOfDay(for: $0) }
            .filter { day in
                day >= startDay && day <= endDay
            }
    }

    private static func completedActivityStarts(
        for task: RoutineTask,
        logs: [RoutineLog],
        on dates: [Date],
        calendar: Calendar
    ) -> [Date] {
        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard !visibleDayKeys.isEmpty else { return [] }

        var startsByDayKey: [String: Date] = [:]
        func record(_ timestamp: Date?) {
            guard let timestamp else { return }
            let startDate = calendar.startOfDay(for: timestamp)
            let dayKey = DayPlanStorage.dayKey(for: startDate, calendar: calendar)
            guard visibleDayKeys.contains(dayKey) else { return }
            startsByDayKey[dayKey] = startDate
        }

        logs
            .filter { $0.kind == .completed }
            .forEach { record($0.timestamp) }
        record(task.lastDone)

        return startsByDayKey.values.sorted()
    }

    private static func deduplicatedAllDaySpans(
        _ spans: [AllDaySpan],
        calendar: Calendar
    ) -> [AllDaySpan] {
        var seenDayKeys = Set<String>()
        var accepted: [AllDaySpan] = []
        let sortedSpans = spans.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }
            return lhs.endDate > rhs.endDate
        }

        for span in sortedSpans {
            let dayKey = DayPlanStorage.dayKey(for: span.startDate, calendar: calendar)
            guard seenDayKeys.insert(dayKey).inserted else { continue }
            let isContained = accepted.contains { existing in
                existing.startDate <= span.startDate && existing.endDate >= span.endDate
            }
            guard !isContained else { continue }
            accepted.append(span)
        }
        return accepted
    }

    private static func routineAllDayOccurrenceStarts(
        for task: RoutineTask,
        on dates: [Date],
        spanDays: Int,
        calendar: Calendar
    ) -> [Date] {
        guard !task.isOneOffTask,
              let firstDate = dates.first,
              let lastDate = dates.last else { return [] }

        let lookbackDays = max(RoutineTask.sanitizedAllDaySpanDays(spanDays) - 1, 0)
        let firstVisibleDay = calendar.startOfDay(for: firstDate)
        let lastVisibleDay = calendar.startOfDay(for: lastDate)
        var candidateDay = calendar.date(byAdding: .day, value: -lookbackDays, to: firstVisibleDay) ?? firstVisibleDay
        var starts: [Date] = []

        while candidateDay <= lastVisibleDay {
            if routineOccurs(task, on: candidateDay, calendar: calendar) {
                starts.append(candidateDay)
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: candidateDay),
                  nextDay > candidateDay else {
                break
            }
            candidateDay = nextDay
        }
        return starts
    }

    private static func routineOccurs(
        _ task: RoutineTask,
        on day: Date,
        calendar: Calendar
    ) -> Bool {
        switch task.recurrenceRule.kind {
        case .dailyTime:
            return true

        case .weekly:
            let weekday = task.recurrenceRule.weekday ?? calendar.firstWeekday
            return calendar.component(.weekday, from: day) == weekday

        case .monthlyDay:
            let dayOfMonth = clampedDayOfMonth(
                task.recurrenceRule.dayOfMonth ?? 1,
                monthContaining: day,
                calendar: calendar
            )
            return calendar.component(.day, from: day) == dayOfMonth

        case .intervalDays:
            let dueDate = RoutineDateMath.upcomingDueDate(
                for: task,
                referenceDate: day,
                calendar: calendar
            )
            return calendar.isDate(dueDate, inSameDayAs: day)
        }
    }

    private static func clampedDayOfMonth(
        _ dayOfMonth: Int,
        monthContaining date: Date,
        calendar: Calendar
    ) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: date) else {
            return min(max(dayOfMonth, 1), 31)
        }
        return min(max(dayOfMonth, range.lowerBound), range.upperBound - 1)
    }

    private static func normalizedEndDate(
        startDate: Date,
        endDate: Date,
        calendar: Calendar
    ) -> Date {
        let startDay = calendar.startOfDay(for: startDate)
        guard endDate > startDate else {
            return calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        }

        let endDay = calendar.startOfDay(for: endDate)
        if endDay <= startDay {
            return calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        }

        if hasExplicitTime(endDate, calendar: calendar) {
            return calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        }

        return endDay
    }

    private static func hasExplicitTime(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return (components.hour ?? 0) != 0
            || (components.minute ?? 0) != 0
            || (components.second ?? 0) != 0
            || (components.nanosecond ?? 0) != 0
    }
}

enum DayPlanEventBlocks {
    static func blocksByDayKey(
        on dates: [Date],
        from events: [RoutineEvent],
        calendar: Calendar
    ) -> [String: [DayPlanEventBlock]] {
        let visibleDates = dates.map { calendar.startOfDay(for: $0) }
        guard !visibleDates.isEmpty else { return [:] }

        let blocks = events.flatMap { event in
            blocksForEvent(event, on: visibleDates, calendar: calendar)
        }

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

    private static func blocksForEvent(
        _ event: RoutineEvent,
        on visibleDates: [Date],
        calendar: Calendar
    ) -> [DayPlanEventBlock] {
        guard !event.isAllDay,
              let startedAt = event.startedAt else {
            return []
        }

        let endedAt = event.endedAt ?? startedAt.addingTimeInterval(60 * 60)
        guard endedAt > startedAt else { return [] }

        return visibleDates.compactMap { visibleDate -> DayPlanEventBlock? in
            let dayStart = calendar.startOfDay(for: visibleDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return nil
            }

            let intervalStart = max(startedAt, dayStart)
            let intervalEnd = min(endedAt, dayEnd)
            guard intervalEnd > intervalStart else { return nil }

            let dayKey = DayPlanStorage.dayKey(for: dayStart, calendar: calendar)
            let startMinute = Self.startMinute(for: intervalStart, calendar: calendar)
            let rawDuration = max(1, Int(ceil(intervalEnd.timeIntervalSince(intervalStart) / 60)))
            let durationMinutes = DayPlanBlock.clampedDuration(rawDuration, startMinute: startMinute)
            let block = DayPlanBlock(
                id: event.id,
                taskID: event.id,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: event.displayTitle,
                emojiSnapshot: event.displayEmoji,
                createdAt: startedAt,
                updatedAt: endedAt
            )
            return DayPlanEventBlock(eventID: event.id, block: block)
        }
    }

    private static func startMinute(for timestamp: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
    }
}
