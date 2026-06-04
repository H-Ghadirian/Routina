import Foundation

struct DayPlanSleepBlock: Identifiable, Equatable {
    var sessionID: UUID
    var sourceSessionIDs: Set<UUID>
    var block: DayPlanBlock
    var interval: DayPlanBlockedInterval

    var id: String {
        "sleep-\(sessionID.uuidString)-\(block.dayKey)"
    }

    func contains(sessionID: UUID?) -> Bool {
        guard let sessionID else { return false }
        return self.sessionID == sessionID || sourceSessionIDs.contains(sessionID)
    }
}

struct DayPlanAwayBlock: Identifiable, Equatable {
    var sessionID: UUID
    var block: DayPlanBlock
    var interval: DayPlanBlockedInterval

    var id: String {
        "away-\(sessionID.uuidString)-\(block.dayKey)"
    }
}

enum DayPlanSleepBlocks {
    static func blocksByDayKey(
        on dates: [Date],
        from sessions: [SleepSession],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [String: [DayPlanSleepBlock]] {
        let visibleDates = dates.map { calendar.startOfDay(for: $0) }
        guard !visibleDates.isEmpty else { return [:] }

        let blocks = mergedIntervals(
            from: sessions,
            referenceDate: referenceDate
        )
        .flatMap { interval in
            blocksForInterval(
                interval,
                on: visibleDates,
                calendar: calendar
            )
        }

        return Dictionary(grouping: blocks, by: \.block.dayKey)
            .mapValues {
                $0.sorted { lhs, rhs in
                    if lhs.block.startMinute != rhs.block.startMinute {
                        return lhs.block.startMinute < rhs.block.startMinute
                    }
                    return lhs.block.createdAt < rhs.block.createdAt
                }
            }
    }

    static func blockedIntervalsByDayKey(
        on dates: [Date],
        from sessions: [SleepSession],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [String: [DayPlanBlockedInterval]] {
        blocksByDayKey(
            on: dates,
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .mapValues { blocks in
            blocks.map(\.interval)
        }
    }

    static func blockedIntervals(
        on date: Date,
        from sessions: [SleepSession],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [DayPlanBlockedInterval] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return blockedIntervalsByDayKey(
            on: [date],
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )[dayKey] ?? []
    }

    static func conflictingInterval(
        on date: Date,
        from sessions: [SleepSession],
        startMinute: Int,
        durationMinutes: Int,
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> DayPlanBlockedInterval? {
        blockedIntervals(
            on: date,
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .first {
            $0.overlaps(startMinute: startMinute, durationMinutes: durationMinutes)
        }
    }

    private static func blocksForInterval(
        _ sleepInterval: SleepInterval,
        on visibleDates: [Date],
        calendar: Calendar
    ) -> [DayPlanSleepBlock] {
        let startedAt = sleepInterval.startedAt
        let endedAt = sleepInterval.endedAt

        return visibleDates.compactMap { visibleDate -> DayPlanSleepBlock? in
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
                id: sleepInterval.sessionID,
                taskID: sleepInterval.sessionID,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: "Sleep",
                emojiSnapshot: "🛌",
                createdAt: startedAt,
                updatedAt: endedAt
            )
            let interval = DayPlanBlockedInterval(
                dayKey: dayKey,
                startMinute: block.startMinute,
                endMinute: block.endMinute,
                title: "Sleep"
            )

            return DayPlanSleepBlock(
                sessionID: sleepInterval.sessionID,
                sourceSessionIDs: sleepInterval.sourceSessionIDs,
                block: block,
                interval: interval
            )
        }
    }

    private static func mergedIntervals(
        from sessions: [SleepSession],
        referenceDate: Date
    ) -> [SleepInterval] {
        let intervals = sessions.compactMap { session -> SleepInterval? in
            guard let startedAt = session.startedAt else { return nil }
            let endedAt = session.endedAt ?? referenceDate
            guard endedAt > startedAt else { return nil }
            return SleepInterval(
                sessionID: session.id,
                sourceSessionIDs: [session.id],
                startedAt: startedAt,
                endedAt: endedAt
            )
        }
        .sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt {
                return lhs.startedAt < rhs.startedAt
            }
            if lhs.endedAt != rhs.endedAt {
                return lhs.endedAt > rhs.endedAt
            }
            return lhs.sessionID.uuidString < rhs.sessionID.uuidString
        }

        var merged: [SleepInterval] = []
        for interval in intervals {
            guard var last = merged.last else {
                merged.append(interval)
                continue
            }

            if interval.startedAt < last.endedAt {
                last.endedAt = max(last.endedAt, interval.endedAt)
                last.sourceSessionIDs.formUnion(interval.sourceSessionIDs)
                merged[merged.count - 1] = last
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    private struct SleepInterval {
        var sessionID: UUID
        var sourceSessionIDs: Set<UUID>
        var startedAt: Date
        var endedAt: Date
    }

    private static func startMinute(for timestamp: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: timestamp)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
    }
}

enum DayPlanAwayBlocks {
    static func blocksByDayKey(
        on dates: [Date],
        from sessions: [AwaySession],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [String: [DayPlanAwayBlock]] {
        let visibleDates = dates.map { calendar.startOfDay(for: $0) }
        guard !visibleDates.isEmpty else { return [:] }

        let blocks = sessions.flatMap { session in
            blocksForSession(
                for: session,
                on: visibleDates,
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
                    return lhs.block.createdAt < rhs.block.createdAt
                }
            }
    }

    static func blockedIntervalsByDayKey(
        on dates: [Date],
        from sessions: [AwaySession],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [String: [DayPlanBlockedInterval]] {
        blocksByDayKey(
            on: dates,
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .mapValues { blocks in
            blocks.map(\.interval)
        }
    }

    static func blockedIntervals(
        on date: Date,
        from sessions: [AwaySession],
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> [DayPlanBlockedInterval] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return blockedIntervalsByDayKey(
            on: [date],
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )[dayKey] ?? []
    }

    static func conflictingInterval(
        on date: Date,
        from sessions: [AwaySession],
        startMinute: Int,
        durationMinutes: Int,
        referenceDate: Date = Date(),
        calendar: Calendar
    ) -> DayPlanBlockedInterval? {
        blockedIntervals(
            on: date,
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        .first {
            $0.overlaps(startMinute: startMinute, durationMinutes: durationMinutes)
        }
    }

    private static func blocksForSession(
        for session: AwaySession,
        on visibleDates: [Date],
        referenceDate: Date,
        calendar: Calendar
    ) -> [DayPlanAwayBlock] {
        guard let startedAt = session.startedAt else { return [] }

        let endedAt = session.finishedAt ?? session.plannedEndAt ?? referenceDate
        guard endedAt > startedAt else { return [] }

        return visibleDates.compactMap { visibleDate -> DayPlanAwayBlock? in
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
            let durationMinutes = DayPlanBlock.clampedDuration(
                rawDuration,
                startMinute: startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            let block = DayPlanBlock(
                id: session.id,
                taskID: session.id,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: session.displayTitle,
                emojiSnapshot: nil,
                createdAt: startedAt,
                updatedAt: endedAt,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            let interval = DayPlanBlockedInterval(
                dayKey: dayKey,
                startMinute: block.startMinute,
                endMinute: block.endMinute,
                title: session.displayTitle
            )

            return DayPlanAwayBlock(
                sessionID: session.id,
                block: block,
                interval: interval
            )
        }
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

enum DayPlanFormatting {
    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let minutes):
            return "\(minutes)m"
        case (let hours, 0):
            return "\(hours)h"
        default:
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    static func hourText(for hour: Int, on date: Date, calendar: Calendar) -> String {
        timeText(for: hour * 60, on: date, calendar: calendar)
    }

    static func timeText(for minute: Int, on date: Date, calendar: Calendar) -> String {
        let startOfDay = calendar.startOfDay(for: date)
        let clampedMinute = min(max(minute, 0), DayPlanBlock.minutesPerDay)
        let time = calendar.date(byAdding: .minute, value: clampedMinute, to: startOfDay) ?? startOfDay
        return time.formatted(date: .omitted, time: .shortened)
    }
}
