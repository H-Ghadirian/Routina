import Foundation

enum FocusDurationStats {
    static func points(
        for range: DoneChartRange,
        sessions: [FocusSession],
        sprintSessions: [SprintFocusSessionRecord] = [],
        tasks: [RoutineTask] = [],
        boardSprints: [BoardSprintRecord] = [],
        earliestActivityDate: Date? = nil,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [FocusDurationChartPoint] {
        let effectiveReferenceDate = range.referenceDate(relativeTo: referenceDate)
        let endDate = calendar.startOfDay(for: effectiveReferenceDate)
        let defaultStart = range.startDate(relativeTo: referenceDate, calendar: calendar)

        let startDate: Date
        if range == .year, let earliestActivityDate {
            let earliestDay = calendar.startOfDay(for: earliestActivityDate)
            startDate = min(max(earliestDay, defaultStart), endDate)
        } else {
            startDate = defaultStart
        }

        let dayCount = (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1

        let taskTitlesByID = Dictionary(
            uniqueKeysWithValues: tasks.map {
                ($0.id, RoutineTask.trimmedName($0.name) ?? "Untitled task")
            }
        )
        let sprintTitlesByID = boardSprints.reduce(into: [UUID: String]()) { titles, sprint in
            titles[sprint.id] = sprint.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var secondsByDay: [Date: TimeInterval] = [:]
        var contributionsByDay: [Date: [String: FocusContributionAccumulator]] = [:]

        sessions.forEach { session in
            guard let contribution = focusContribution(
                for: session,
                referenceDate: referenceDate,
                calendar: calendar
            ) else {
                return
            }
            let day = contribution.day
            guard day >= startDate, day <= endDate else { return }

            let seconds = contribution.seconds
            guard seconds > 0 else { return }

            secondsByDay[day, default: 0] += seconds

            let taskID = session.taskID
            let title: String
            if let tagTitle = session.focusTagTitle {
                title = tagTitle
            } else if taskID == FocusSession.unassignedTaskID {
                title = "Unassigned focus"
            } else {
                title = taskTitlesByID[taskID] ?? "Unknown task"
            }

            let key: String
            let contributionTaskID: UUID?
            if let normalizedTag = session.focusTagName.flatMap(RoutineTag.normalized) {
                key = "tag-\(normalizedTag)"
                contributionTaskID = nil
            } else if taskID == FocusSession.unassignedTaskID {
                key = "unassigned-focus"
                contributionTaskID = nil
            } else {
                key = "task-\(taskID.uuidString)"
                contributionTaskID = taskID
            }

            var accumulator = contributionsByDay[day, default: [:]][key]
                ?? FocusContributionAccumulator(taskID: contributionTaskID, title: title)
            accumulator.seconds += seconds
            accumulator.sessionCount += 1
            contributionsByDay[day, default: [:]][key] = accumulator
        }

        sprintSessions.forEach { session in
            guard let contribution = focusContribution(
                for: session,
                referenceDate: referenceDate,
                calendar: calendar
            ) else {
                return
            }
            let day = contribution.day
            guard day >= startDate, day <= endDate else { return }

            let seconds = contribution.seconds
            guard seconds > 0 else { return }

            secondsByDay[day, default: 0] += seconds

            let title = sprintTitlesByID[session.sprintID].flatMap { $0.isEmpty ? nil : $0 }
                ?? "Board focus"
            let key = "sprint-\(session.sprintID.uuidString)"
            var accumulator = contributionsByDay[day, default: [:]][key]
                ?? FocusContributionAccumulator(taskID: nil, title: title)
            accumulator.seconds += seconds
            accumulator.sessionCount += 1
            contributionsByDay[day, default: [:]][key] = accumulator
        }

        return (0..<dayCount).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                return nil
            }

            return FocusDurationChartPoint(
                date: date,
                seconds: secondsByDay[date, default: 0],
                contributions: orderedContributions(
                    from: Array(contributionsByDay[date, default: [:]].values)
                )
            )
        }
    }

    static func groupedPoints(
        from points: [FocusDurationChartPoint],
        by component: Calendar.Component,
        calendar: Calendar = .current
    ) -> [FocusDurationChartPoint] {
        guard component != .day else { return points }

        var bucketOrder: [Date] = []
        var secondsByBucket: [Date: TimeInterval] = [:]
        var contributionsByBucket: [Date: [String: FocusContributionAccumulator]] = [:]

        for point in points {
            let bucketStart = bucketStartDate(for: point.date, component: component, calendar: calendar)
            if secondsByBucket[bucketStart] == nil {
                bucketOrder.append(bucketStart)
            }
            secondsByBucket[bucketStart, default: 0] += point.seconds

            for contribution in point.contributions {
                let key = contribution.taskID?.uuidString ?? "unassigned-\(contribution.title)"
                var accumulator = contributionsByBucket[bucketStart, default: [:]][key]
                    ?? FocusContributionAccumulator(
                        taskID: contribution.taskID,
                        title: contribution.title
                    )
                accumulator.seconds += contribution.seconds
                accumulator.sessionCount += contribution.sessionCount
                contributionsByBucket[bucketStart, default: [:]][key] = accumulator
            }
        }

        return bucketOrder.sorted().map { bucketStart in
            FocusDurationChartPoint(
                date: bucketStart,
                seconds: secondsByBucket[bucketStart, default: 0],
                contributions: orderedContributions(
                    from: Array(contributionsByBucket[bucketStart, default: [:]].values)
                )
            )
        }
    }

    static func totalSeconds(in points: [FocusDurationChartPoint]) -> TimeInterval {
        points.reduce(0) { $0 + $1.seconds }
    }

    static func averageSeconds(in points: [FocusDurationChartPoint]) -> TimeInterval {
        guard !points.isEmpty else { return 0 }
        return totalSeconds(in: points) / Double(points.count)
    }

    static func cumulativePoints(
        from points: [FocusDurationChartPoint]
    ) -> [FocusCumulativeChartPoint] {
        var runningTotal: TimeInterval = 0

        return points.map { point in
            runningTotal += point.seconds
            return FocusCumulativeChartPoint(
                date: point.date,
                dailySeconds: point.seconds,
                cumulativeSeconds: runningTotal
            )
        }
    }

    static func weekdayAveragePoints(
        from points: [FocusDurationChartPoint],
        calendar: Calendar = .current
    ) -> [FocusWeekdayAverageChartPoint] {
        let pointsByWeekday = Dictionary(grouping: points) {
            calendar.component(.weekday, from: $0.date)
        }

        return orderedWeekdays(calendar: calendar).map { weekday in
            let weekdayPoints = pointsByWeekday[weekday] ?? []
            let totalSeconds = weekdayPoints.reduce(0) { $0 + $1.seconds }
            let averageSeconds = weekdayPoints.isEmpty
                ? 0
                : totalSeconds / Double(weekdayPoints.count)

            return FocusWeekdayAverageChartPoint(
                weekday: weekday,
                symbol: weekdaySymbol(for: weekday, calendar: calendar, abbreviated: false),
                shortSymbol: weekdaySymbol(for: weekday, calendar: calendar, abbreviated: true),
                seconds: averageSeconds,
                contributingDayCount: weekdayPoints.count
            )
        }
    }

    static func busiestDay(in points: [FocusDurationChartPoint]) -> FocusDurationChartPoint? {
        points.max { lhs, rhs in
            if lhs.seconds == rhs.seconds {
                return lhs.date > rhs.date
            }
            return lhs.seconds < rhs.seconds
        }
    }

    static func strongestWeekdayAverage(
        in points: [FocusWeekdayAverageChartPoint]
    ) -> FocusWeekdayAverageChartPoint? {
        var strongest: FocusWeekdayAverageChartPoint?

        for point in points {
            guard let currentStrongest = strongest else {
                strongest = point
                continue
            }

            if point.seconds > currentStrongest.seconds {
                strongest = point
            }
        }

        return strongest
    }

    private static func orderedWeekdays(calendar: Calendar) -> [Int] {
        let firstWeekday = min(max(calendar.firstWeekday, 1), 7)
        return (0..<7).map { offset in
            ((firstWeekday - 1 + offset) % 7) + 1
        }
    }

    private static func weekdaySymbol(
        for weekday: Int,
        calendar: Calendar,
        abbreviated: Bool
    ) -> String {
        let symbols = abbreviated ? calendar.shortWeekdaySymbols : calendar.weekdaySymbols
        guard !symbols.isEmpty else { return "\(weekday)" }
        let index = min(max(weekday - 1, 0), symbols.count - 1)
        return symbols[index]
    }

    private static func bucketStartDate(
        for date: Date,
        component: Calendar.Component,
        calendar: Calendar
    ) -> Date {
        switch component {
        case .weekOfYear:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start
                ?? calendar.startOfDay(for: date)
        default:
            return calendar.startOfDay(for: date)
        }
    }

    private static func focusContribution(
        for session: FocusSession,
        referenceDate: Date,
        calendar: Calendar
    ) -> (day: Date, seconds: TimeInterval)? {
        switch session.state {
        case .completed:
            guard let daySource = session.completedAt ?? session.startedAt else {
                return nil
            }
            return (
                day: calendar.startOfDay(for: daySource),
                seconds: session.actualDurationSeconds
            )

        case .active:
            let day = calendar.startOfDay(for: referenceDate)
            return (
                day: day,
                seconds: activeFocusSecondsOnReferenceDay(
                    startedAt: session.startedAt,
                    pausedAt: session.pausedAt,
                    activeSeconds: session.activeDurationSeconds(at: referenceDate),
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            )

        case .abandoned:
            return nil
        }
    }

    private static func focusContribution(
        for session: SprintFocusSessionRecord,
        referenceDate: Date,
        calendar: Calendar
    ) -> (day: Date, seconds: TimeInterval)? {
        if let stoppedAt = session.stoppedAt {
            return (
                day: calendar.startOfDay(for: stoppedAt),
                seconds: session.activeDurationSeconds(at: referenceDate)
            )
        }

        return (
            day: calendar.startOfDay(for: referenceDate),
            seconds: activeFocusSecondsOnReferenceDay(
                startedAt: session.startedAt,
                pausedAt: session.pausedAt,
                activeSeconds: session.activeDurationSeconds(at: referenceDate),
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }

    private static func activeFocusSecondsOnReferenceDay(
        startedAt: Date?,
        pausedAt: Date?,
        activeSeconds: TimeInterval,
        referenceDate: Date,
        calendar: Calendar
    ) -> TimeInterval {
        guard let startedAt, startedAt <= referenceDate else {
            return 0
        }

        let dayStart = calendar.startOfDay(for: referenceDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              startedAt < dayEnd else {
            return 0
        }

        let endedAt = min(pausedAt ?? referenceDate, referenceDate)
        let dayRangeStart = max(startedAt, dayStart)
        let dayRangeEnd = min(endedAt, referenceDate)
        let wallClockSecondsOnDay = max(0, dayRangeEnd.timeIntervalSince(dayRangeStart))
        return min(max(0, activeSeconds), wallClockSecondsOnDay)
    }

    private static func orderedContributions(
        from accumulators: [FocusContributionAccumulator]
    ) -> [FocusDurationContribution] {
        accumulators
            .map {
                FocusDurationContribution(
                    taskID: $0.taskID,
                    title: $0.title,
                    seconds: $0.seconds,
                    sessionCount: $0.sessionCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.seconds != rhs.seconds {
                    return lhs.seconds > rhs.seconds
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private struct FocusContributionAccumulator {
        let taskID: UUID?
        let title: String
        var seconds: TimeInterval = 0
        var sessionCount: Int = 0
    }
}

enum Focus2048Stats {
    static let baseTileSeconds: TimeInterval = 2 * 60 * 60

    static func board(totalFocusSeconds: TimeInterval) -> Focus2048Board {
        let safeTotalSeconds = max(0, totalFocusSeconds)
        let completedBaseTileCount = Int(safeTotalSeconds / baseTileSeconds)
        let partialTileSeconds = safeTotalSeconds - TimeInterval(completedBaseTileCount) * baseTileSeconds
        let tiles = tiles(for: completedBaseTileCount)

        return Focus2048Board(
            tiles: tiles,
            totalFocusSeconds: safeTotalSeconds,
            completedBaseTileCount: completedBaseTileCount,
            partialTileSeconds: partialTileSeconds,
            baseTileSeconds: baseTileSeconds
        )
    }

    private static func tiles(for completedBaseTileCount: Int) -> [Focus2048Tile] {
        guard completedBaseTileCount > 0 else { return [] }

        var remaining = completedBaseTileCount
        var bitIndex = 0
        var tiles: [Focus2048Tile] = []

        while remaining > 0 {
            if remaining & 1 == 1 {
                tiles.append(
                    Focus2048Tile(
                        id: bitIndex,
                        value: 2 << bitIndex
                    )
                )
            }

            remaining >>= 1
            bitIndex += 1
        }

        return tiles.sorted { lhs, rhs in
            lhs.value > rhs.value
        }
    }
}
