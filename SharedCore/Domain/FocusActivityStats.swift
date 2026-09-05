import Foundation

struct FocusDurationChartPoint: Equatable, Identifiable {
    let date: Date
    let seconds: TimeInterval
    let contributions: [FocusDurationContribution]

    init(
        date: Date,
        seconds: TimeInterval,
        contributions: [FocusDurationContribution] = []
    ) {
        self.date = date
        self.seconds = seconds
        self.contributions = contributions
    }

    var id: Date { date }

    var minutes: Double {
        seconds / 60
    }
}

struct FocusDurationContribution: Equatable, Identifiable {
    let taskID: UUID?
    let title: String
    let seconds: TimeInterval
    let sessionCount: Int

    var id: String {
        taskID?.uuidString ?? "unassigned-\(title)"
    }

    var minutes: Double {
        seconds / 60
    }
}

struct FocusCumulativeChartPoint: Equatable, Identifiable {
    let date: Date
    let dailySeconds: TimeInterval
    let cumulativeSeconds: TimeInterval

    var id: Date { date }

    var dailyMinutes: Double {
        dailySeconds / 60
    }

    var cumulativeMinutes: Double {
        cumulativeSeconds / 60
    }
}

struct Focus2048Tile: Equatable, Identifiable {
    let id: Int
    let value: Int

    var representedSeconds: TimeInterval {
        TimeInterval(value) * 60 * 60
    }
}

struct Focus2048Board: Equatable {
    static let cellCount = 16

    let tiles: [Focus2048Tile]
    let totalFocusSeconds: TimeInterval
    let completedBaseTileCount: Int
    let partialTileSeconds: TimeInterval
    let baseTileSeconds: TimeInterval

    var largestTileValue: Int {
        tiles.map(\.value).max() ?? 0
    }

    var secondsUntilNextBaseTile: TimeInterval {
        guard baseTileSeconds > 0 else { return 0 }
        if partialTileSeconds <= 0 {
            return baseTileSeconds
        }
        return max(0, baseTileSeconds - partialTileSeconds)
    }

    var nextTileProgress: Double {
        guard baseTileSeconds > 0 else { return 0 }
        return min(max(partialTileSeconds / baseTileSeconds, 0), 1)
    }
}

struct FocusWorkChartPoint: Equatable, Identifiable {
    let date: Date
    let focusSeconds: TimeInterval
    let doneCount: Int

    var id: Date { date }

    var focusMinutes: Double {
        focusSeconds / 60
    }

    var hasActivity: Bool {
        focusSeconds > 0 || doneCount > 0
    }

    var hasFocusAndDone: Bool {
        focusSeconds > 0 && doneCount > 0
    }
}

struct HourlyActivityChartPoint: Equatable, Identifiable {
    let hour: Int
    let focusSeconds: TimeInterval
    let doneCount: Int
    let createdCount: Int
    let activityCount: Int

    var id: Int { hour }

    var focusMinutes: Double {
        focusSeconds / 60
    }

    var hasActivity: Bool {
        focusSeconds > 0 || doneCount > 0 || createdCount > 0 || activityCount > 0
    }
}

struct FocusWeekdayAverageChartPoint: Equatable, Identifiable {
    let weekday: Int
    let symbol: String
    let shortSymbol: String
    let seconds: TimeInterval
    let contributingDayCount: Int

    var id: Int { weekday }

    var minutes: Double {
        seconds / 60
    }
}

enum FocusWorkStats {
    static func points(
        outcomePoints: [OutcomeMixChartPoint],
        focusPoints: [FocusDurationChartPoint]
    ) -> [FocusWorkChartPoint] {
        let focusByDate = Dictionary(uniqueKeysWithValues: focusPoints.map { ($0.date, $0.seconds) })

        return outcomePoints.map { outcomePoint in
            FocusWorkChartPoint(
                date: outcomePoint.date,
                focusSeconds: focusByDate[outcomePoint.date, default: 0],
                doneCount: outcomePoint.doneCount
            )
        }
    }

    static func strongestPairedDay(in points: [FocusWorkChartPoint]) -> FocusWorkChartPoint? {
        points
            .filter(\.hasFocusAndDone)
            .max { lhs, rhs in
                if lhs.doneCount == rhs.doneCount {
                    if lhs.focusSeconds == rhs.focusSeconds {
                        return lhs.date > rhs.date
                    }
                    return lhs.focusSeconds < rhs.focusSeconds
                }
                return lhs.doneCount < rhs.doneCount
            }
    }
}

enum HourlyActivityStats {
    static func points(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession],
        sprintFocusSessions: [SprintFocusSessionRecord] = [],
        focusSessionEvents: [FocusSessionActionEvent] = [],
        selectedRange: DoneChartRange,
        earliestActivityDate: Date? = nil,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [HourlyActivityChartPoint] {
        let range = dateRange(
            selectedRange: selectedRange,
            earliestActivityDate: earliestActivityDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let focusSecondsByHour = hourlyFocusSeconds(
            taskSessions: focusSessions,
            sprintSessions: sprintFocusSessions,
            events: focusSessionEvents,
            range: range,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let doneCountsByHour = logs.reduce(into: [Int: Int]()) { partialResult, log in
            guard log.kind == .completed,
                let timestamp = log.timestamp,
                timestamp >= range.start,
                timestamp < range.end
            else {
                return
            }

            partialResult[calendar.component(.hour, from: timestamp), default: 0] += 1
        }

        let activityCountsByHour = logs.reduce(into: [Int: Int]()) { partialResult, log in
            guard let timestamp = log.timestamp,
                timestamp >= range.start,
                timestamp < range.end
            else {
                return
            }

            partialResult[calendar.component(.hour, from: timestamp), default: 0] += 1
        }

        let createdCountsByHour = tasks.reduce(into: [Int: Int]()) { partialResult, task in
            guard let createdAt = task.createdAt,
                createdAt >= range.start,
                createdAt < range.end
            else {
                return
            }

            partialResult[calendar.component(.hour, from: createdAt), default: 0] += 1
        }

        return (0..<24).map { hour in
            HourlyActivityChartPoint(
                hour: hour,
                focusSeconds: focusSecondsByHour[hour, default: 0],
                doneCount: doneCountsByHour[hour, default: 0],
                createdCount: createdCountsByHour[hour, default: 0],
                activityCount: activityCountsByHour[hour, default: 0]
            )
        }
    }

    private static func dateRange(
        selectedRange: DoneChartRange,
        earliestActivityDate: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let endDay = calendar.startOfDay(
            for: selectedRange.referenceDate(relativeTo: referenceDate)
        )
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? referenceDate
        let defaultStart = selectedRange.startDate(
            relativeTo: referenceDate,
            calendar: calendar
        )

        if selectedRange == .year, let earliestActivityDate {
            let earliestDay = calendar.startOfDay(for: earliestActivityDate)
            return (min(max(earliestDay, defaultStart), endDay), end)
        }

        return (defaultStart, end)
    }

    private static func hourlyFocusSeconds(
        taskSessions: [FocusSession],
        sprintSessions: [SprintFocusSessionRecord],
        events: [FocusSessionActionEvent],
        range: (start: Date, end: Date),
        referenceDate: Date,
        calendar: Calendar
    ) -> [Int: TimeInterval] {
        let canonicalSessions = FocusStatsSessionCanonicalization.canonicalSessions(
            taskSessions: taskSessions,
            sprintSessions: sprintSessions
        )
        let eventsBySessionID = FocusActivityIntervalResolver.eventsBySessionID(events)
        var secondsByHour: [Int: TimeInterval] = [:]

        for session in canonicalSessions.taskSessions {
            let intervals = FocusActivityIntervalResolver.intervals(
                for: session,
                events: eventsBySessionID[session.id] ?? [],
                referenceDate: referenceDate
            )
            for interval in intervals {
                allocateFocusInterval(
                    from: max(interval.startedAt, range.start),
                    to: min(interval.endedAt, range.end),
                    into: &secondsByHour,
                    calendar: calendar
                )
            }
        }

        for session in canonicalSessions.sprintSessions {
            let intervals = FocusActivityIntervalResolver.intervals(
                for: session,
                events: eventsBySessionID[session.id] ?? [],
                referenceDate: referenceDate
            )
            for interval in intervals {
                allocateFocusInterval(
                    from: max(interval.startedAt, range.start),
                    to: min(interval.endedAt, range.end),
                    into: &secondsByHour,
                    calendar: calendar
                )
            }
        }

        return secondsByHour
    }

    private static func allocateFocusInterval(
        from startedAt: Date,
        to endedAt: Date,
        into focusSecondsByHour: inout [Int: TimeInterval],
        calendar: Calendar
    ) {
        guard endedAt > startedAt else { return }
        var cursor = startedAt

        while cursor < endedAt {
            let hour = calendar.component(.hour, from: cursor)
            let hourEnd = calendar.dateInterval(of: .hour, for: cursor)?.end ?? endedAt
            let segmentEnd = min(hourEnd, endedAt)
            guard segmentEnd > cursor else { break }

            let segmentSeconds = segmentEnd.timeIntervalSince(cursor)
            focusSecondsByHour[hour, default: 0] += segmentSeconds
            cursor = segmentEnd
        }
    }
}
