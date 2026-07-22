import Foundation

enum DoneChartRange: String, CaseIterable, Equatable, Identifiable, Codable, Sendable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: Self { self }

    var trailingDayCount: Int {
        switch self {
        case .today:
            return 1
        case .week:
            return 7
        case .month:
            return 30
        case .year:
            return 365
        }
    }

    var periodDescription: String {
        switch self {
        case .today:
            return "Today"
        case .week:
            return "Last 7 days"
        case .month:
            return "Last 30 days"
        case .year:
            return "Last 365 days"
        }
    }
}

struct DoneChartPoint: Equatable, Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
}

struct OutcomeMixChartPoint: Equatable, Identifiable {
    let date: Date
    let doneCount: Int
    let missedCount: Int
    let canceledCount: Int

    var id: Date { date }

    var totalCount: Int {
        doneCount + missedCount + canceledCount
    }

    func count(for kind: RoutineLogKind) -> Int {
        switch kind {
        case .completed:
            return doneCount
        case .fulfilled:
            return 0
        case .missed:
            return missedCount
        case .canceled:
            return canceledCount
        }
    }
}

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

struct EstimateActualChartPoint: Equatable, Identifiable {
    let date: Date
    let estimatedMinutes: Int
    let actualMinutes: Int
    let trackedCompletionCount: Int

    var id: Date { date }

    var deltaMinutes: Int {
        actualMinutes - estimatedMinutes
    }

    var absoluteDeltaMinutes: Int {
        abs(deltaMinutes)
    }

    var hasTrackedTime: Bool {
        estimatedMinutes > 0 || actualMinutes > 0
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

struct TagUsageChartPoint: Equatable, Identifiable {
    let name: String
    let completionCount: Int
    let linkedRoutineCount: Int
    let linkedTodoCount: Int
    let colorHex: String?

    var id: String {
        RoutineTag.normalized(name) ?? name
    }

    var bubbleValue: Int {
        max(completionCount, linkedRoutineCount)
    }
}

struct GoalProgressChartPoint: Equatable, Identifiable {
    let goalID: UUID
    let title: String
    let emoji: String
    let color: RoutineTaskColor
    let linkedTaskCount: Int
    let completedTaskCount: Int
    let completionCount: Int
    let focusSeconds: TimeInterval
    let targetDate: Date?

    var id: UUID { goalID }

    var completionRatio: Double {
        guard linkedTaskCount > 0 else { return 0 }
        return min(Double(completedTaskCount) / Double(linkedTaskCount), 1)
    }

    var focusMinutes: Double {
        focusSeconds / 60
    }
}

struct EmotionTrendChartPoint: Equatable, Identifiable {
    let date: Date
    let logCount: Int
    let averageValence: Double
    let averageArousal: Double
    let averageIntensity: Double

    var id: Date { date }
}

enum RoutineCompletionStats {
    static func outcomePoints(
        for range: DoneChartRange,
        logs: [RoutineLog],
        earliestActivityDate: Date? = nil,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [OutcomeMixChartPoint] {
        let endDate = calendar.startOfDay(for: referenceDate)
        guard let defaultStart = calendar.date(byAdding: .day, value: -(range.trailingDayCount - 1), to: endDate) else {
            return []
        }

        let startDate: Date
        if range == .year, let earliestActivityDate {
            let earliestDay = calendar.startOfDay(for: earliestActivityDate)
            startDate = min(max(earliestDay, defaultStart), endDate)
        } else {
            startDate = defaultStart
        }

        let dayCount = (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
        let countsByDay = logs.reduce(into: [Date: [RoutineLogKind: Int]]()) { partialResult, log in
            guard let timestamp = log.timestamp else { return }
            let day = calendar.startOfDay(for: timestamp)
            guard day >= startDate, day <= endDate else { return }
            partialResult[day, default: [:]][log.kind, default: 0] += 1
        }

        return (0..<dayCount).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                return nil
            }

            let counts = countsByDay[date, default: [:]]
            return OutcomeMixChartPoint(
                date: date,
                doneCount: counts[.completed, default: 0],
                missedCount: counts[.missed, default: 0],
                canceledCount: counts[.canceled, default: 0]
            )
        }
    }

    static func points(
        for range: DoneChartRange,
        timestamps: [Date],
        earliestActivityDate: Date? = nil,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [DoneChartPoint] {
        let endDate = calendar.startOfDay(for: referenceDate)
        guard let defaultStart = calendar.date(byAdding: .day, value: -(range.trailingDayCount - 1), to: endDate) else {
            return []
        }

        let startDate: Date
        if range == .year, let earliestActivityDate {
            let earliestDay = calendar.startOfDay(for: earliestActivityDate)
            startDate = min(max(earliestDay, defaultStart), endDate)
        } else {
            startDate = defaultStart
        }

        let dayCount = (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1

        let countsByDay = timestamps.reduce(into: [Date: Int]()) { partialResult, timestamp in
            let day = calendar.startOfDay(for: timestamp)
            guard day >= startDate, day <= endDate else { return }
            partialResult[day, default: 0] += 1
        }

        return (0..<dayCount).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                return nil
            }

            return DoneChartPoint(
                date: date,
                count: countsByDay[date, default: 0]
            )
        }
    }

    static func totalCount(in points: [DoneChartPoint]) -> Int {
        points.reduce(0) { $0 + $1.count }
    }

    static func averageCount(in points: [DoneChartPoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        return Double(totalCount(in: points)) / Double(points.count)
    }

    static func busiestDay(in points: [DoneChartPoint]) -> DoneChartPoint? {
        points.max { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.date > rhs.date
            }
            return lhs.count < rhs.count
        }
    }

    static func tagUsagePoints(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        chartPoints: [DoneChartPoint],
        tagColors: [String: String],
        limit: Int = 12,
        calendar: Calendar = .current
    ) -> [TagUsageChartPoint] {
        guard !tasks.isEmpty else { return [] }

        let taskIDs = Set(tasks.map(\.id))
        let chartDays = Set(chartPoints.map { calendar.startOfDay(for: $0.date) })
        let completionCountsByTaskID = logs.reduce(into: [UUID: Int]()) { partialResult, log in
            guard log.kind == .completed,
                  taskIDs.contains(log.taskID),
                  let timestamp = log.timestamp,
                  chartDays.contains(calendar.startOfDay(for: timestamp)) else {
                return
            }

            partialResult[log.taskID, default: 0] += 1
        }

        let summaries = RoutineTagColors.applying(
            tagColors,
            to: RoutineTag.summaries(from: tasks, countsByTaskID: completionCountsByTaskID)
        )

        return summaries
            .filter { $0.doneCount > 0 || $0.linkedRoutineCount > 0 }
            .map {
                TagUsageChartPoint(
                    name: $0.name,
                    completionCount: $0.doneCount,
                    linkedRoutineCount: $0.linkedRoutineCount,
                    linkedTodoCount: $0.linkedTodoCount,
                    colorHex: $0.colorHex
                )
            }
            .sorted {
                if $0.completionCount != $1.completionCount {
                    return $0.completionCount > $1.completionCount
                }
                if $0.linkedRoutineCount != $1.linkedRoutineCount {
                    return $0.linkedRoutineCount > $1.linkedRoutineCount
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}

enum EmotionTrendStats {
    static func points(
        emotionLogs: [EmotionLog],
        calendar: Calendar = .current
    ) -> [EmotionTrendChartPoint] {
        let logsByDay = Dictionary(grouping: emotionLogs) { emotion in
            calendar.startOfDay(for: emotion.createdAt ?? .distantPast)
        }

        return logsByDay.keys.sorted().compactMap { day in
            guard day != calendar.startOfDay(for: .distantPast),
                  let logs = logsByDay[day],
                  !logs.isEmpty else {
                return nil
            }

            let count = Double(logs.count)
            return EmotionTrendChartPoint(
                date: day,
                logCount: logs.count,
                averageValence: logs.reduce(0) { $0 + $1.valence } / count,
                averageArousal: logs.reduce(0) { $0 + $1.arousal } / count,
                averageIntensity: logs.reduce(0) { $0 + Double($1.clampedIntensity) } / count
            )
        }
    }

    static func highestIntensityDay(in points: [EmotionTrendChartPoint]) -> EmotionTrendChartPoint? {
        points.max { lhs, rhs in
            if lhs.averageIntensity == rhs.averageIntensity {
                return lhs.date > rhs.date
            }
            return lhs.averageIntensity < rhs.averageIntensity
        }
    }
}

enum GoalProgressStats {
    static func points(
        goals: [RoutineGoal],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession],
        outcomePoints: [OutcomeMixChartPoint],
        limit: Int = 8,
        calendar: Calendar = .current
    ) -> [GoalProgressChartPoint] {
        let chartDays = Set(outcomePoints.map { calendar.startOfDay(for: $0.date) })
        guard !chartDays.isEmpty else { return [] }

        let activeGoals = goals.filter { $0.status == .active }
        let activeGoalIDs = Set(activeGoals.map(\.id))
        guard !activeGoalIDs.isEmpty else { return [] }

        var activeGoalIDsByTaskID: [UUID: [UUID]] = [:]
        for task in tasks {
            activeGoalIDsByTaskID[task.id] = task.goalIDs.filter { activeGoalIDs.contains($0) }
        }
        let linkedTaskIDsByGoalID = tasks.reduce(into: [UUID: Set<UUID>]()) { partialResult, task in
            for goalID in activeGoalIDsByTaskID[task.id, default: []] {
                partialResult[goalID, default: []].insert(task.id)
            }
        }

        var completedTaskIDsByGoalID: [UUID: Set<UUID>] = [:]
        var completionCountsByGoalID: [UUID: Int] = [:]
        for log in logs {
            guard log.kind == .completed,
                  let timestamp = log.timestamp,
                  chartDays.contains(calendar.startOfDay(for: timestamp)) else {
                continue
            }

            for goalID in activeGoalIDsByTaskID[log.taskID, default: []] {
                completedTaskIDsByGoalID[goalID, default: []].insert(log.taskID)
                completionCountsByGoalID[goalID, default: 0] += 1
            }
        }

        var focusSecondsByGoalID: [UUID: TimeInterval] = [:]
        for session in focusSessions {
            guard session.state == .completed,
                  let daySource = session.completedAt ?? session.startedAt,
                  chartDays.contains(calendar.startOfDay(for: daySource)) else {
                continue
            }

            for goalID in activeGoalIDsByTaskID[session.taskID, default: []] {
                focusSecondsByGoalID[goalID, default: 0] += session.actualDurationSeconds
            }
        }

        return activeGoals.compactMap { goal in
            let linkedTaskIDs = linkedTaskIDsByGoalID[goal.id, default: []]
            guard !linkedTaskIDs.isEmpty else { return nil }

            return GoalProgressChartPoint(
                goalID: goal.id,
                title: goal.displayTitle,
                emoji: goal.emoji.flatMap(RoutineGoal.cleanedEmoji) ?? "\u{1F3AF}",
                color: goal.color,
                linkedTaskCount: linkedTaskIDs.count,
                completedTaskCount: completedTaskIDsByGoalID[goal.id, default: []].count,
                completionCount: completionCountsByGoalID[goal.id, default: 0],
                focusSeconds: focusSecondsByGoalID[goal.id, default: 0],
                targetDate: goal.targetDate
            )
        }
        .sorted {
            if $0.focusSeconds != $1.focusSeconds {
                return $0.focusSeconds > $1.focusSeconds
            }
            if $0.completionCount != $1.completionCount {
                return $0.completionCount > $1.completionCount
            }
            if $0.completionRatio != $1.completionRatio {
                return $0.completionRatio > $1.completionRatio
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        .prefix(limit)
        .map { $0 }
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

        var focusSecondsByHour: [Int: TimeInterval] = [:]
        for session in focusSessions {
            guard let contribution = focusContribution(
                for: session,
                range: range,
                referenceDate: referenceDate,
                calendar: calendar
            ) else { continue }
            allocateFocusInterval(
                from: contribution.startedAt,
                to: contribution.endedAt,
                totalSeconds: contribution.seconds,
                into: &focusSecondsByHour,
                calendar: calendar
            )
        }

        for session in sprintFocusSessions {
            guard let contribution = sprintFocusContribution(
                for: session,
                range: range,
                referenceDate: referenceDate,
                calendar: calendar
            ) else { continue }
            allocateFocusInterval(
                from: contribution.startedAt,
                to: contribution.endedAt,
                totalSeconds: contribution.seconds,
                into: &focusSecondsByHour,
                calendar: calendar
            )
        }

        let doneCountsByHour = logs.reduce(into: [Int: Int]()) { partialResult, log in
            guard log.kind == .completed,
                  let timestamp = log.timestamp,
                  timestamp >= range.start,
                  timestamp < range.end else {
                return
            }

            partialResult[calendar.component(.hour, from: timestamp), default: 0] += 1
        }

        let activityCountsByHour = logs.reduce(into: [Int: Int]()) { partialResult, log in
            guard let timestamp = log.timestamp,
                  timestamp >= range.start,
                  timestamp < range.end else {
                return
            }

            partialResult[calendar.component(.hour, from: timestamp), default: 0] += 1
        }

        let createdCountsByHour = tasks.reduce(into: [Int: Int]()) { partialResult, task in
            guard let createdAt = task.createdAt,
                  createdAt >= range.start,
                  createdAt < range.end else {
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
        let endDay = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? referenceDate
        let defaultStart = calendar.date(
            byAdding: .day,
            value: -(selectedRange.trailingDayCount - 1),
            to: endDay
        ) ?? endDay

        if selectedRange == .year, let earliestActivityDate {
            let earliestDay = calendar.startOfDay(for: earliestActivityDate)
            return (min(max(earliestDay, defaultStart), endDay), end)
        }

        return (defaultStart, end)
    }

    private static func allocateFocusInterval(
        from startedAt: Date,
        to endedAt: Date,
        totalSeconds: TimeInterval,
        into focusSecondsByHour: inout [Int: TimeInterval],
        calendar: Calendar
    ) {
        let wallClockSeconds = endedAt.timeIntervalSince(startedAt)
        guard wallClockSeconds > 0, totalSeconds > 0 else { return }
        let activeRatio = min(1, totalSeconds / wallClockSeconds)
        var cursor = startedAt
        var allocatedSeconds: TimeInterval = 0

        while cursor < endedAt {
            let hour = calendar.component(.hour, from: cursor)
            let hourEnd = calendar.dateInterval(of: .hour, for: cursor)?.end ?? endedAt
            let segmentEnd = min(hourEnd, endedAt)
            guard segmentEnd > cursor else { break }

            let segmentSeconds = segmentEnd.timeIntervalSince(cursor) * activeRatio
            focusSecondsByHour[hour, default: 0] += segmentSeconds
            allocatedSeconds += segmentSeconds
            cursor = segmentEnd
        }

        // Keep the hourly sum identical to the canonical active-duration total despite
        // floating-point rounding while distributing a session across hour boundaries.
        if allocatedSeconds > 0 {
            let finalHour = calendar.component(.hour, from: endedAt.addingTimeInterval(-0.001))
            focusSecondsByHour[finalHour, default: 0] += totalSeconds - allocatedSeconds
        }
    }

    private static func focusContribution(
        for session: FocusSession,
        range: (start: Date, end: Date),
        referenceDate: Date,
        calendar: Calendar
    ) -> (startedAt: Date, endedAt: Date, seconds: TimeInterval)? {
        guard let startedAt = session.startedAt else { return nil }

        switch session.state {
        case .completed:
            guard let completedAt = session.completedAt,
                  completedAt > startedAt,
                  completedAt >= range.start,
                  completedAt < range.end else { return nil }
            return (startedAt, completedAt, session.actualDurationSeconds)

        case .active:
            let dayStart = calendar.startOfDay(for: referenceDate)
            guard dayStart >= range.start, dayStart < range.end else { return nil }
            let intervalStart = max(startedAt, dayStart)
            let intervalEnd = min(session.pausedAt ?? referenceDate, referenceDate)
            let wallClockSeconds = max(0, intervalEnd.timeIntervalSince(intervalStart))
            let activeSeconds = min(
                max(0, session.activeDurationSeconds(at: referenceDate)),
                wallClockSeconds
            )
            guard intervalEnd > intervalStart, activeSeconds > 0 else { return nil }
            return (intervalStart, intervalEnd, activeSeconds)

        case .abandoned:
            return nil
        }
    }

    private static func sprintFocusContribution(
        for session: SprintFocusSessionRecord,
        range: (start: Date, end: Date),
        referenceDate: Date,
        calendar: Calendar
    ) -> (startedAt: Date, endedAt: Date, seconds: TimeInterval)? {
        if let stoppedAt = session.stoppedAt {
            guard stoppedAt > session.startedAt,
                  stoppedAt >= range.start,
                  stoppedAt < range.end else { return nil }
            return (
                session.startedAt,
                stoppedAt,
                session.activeDurationSeconds(at: referenceDate)
            )
        }

        let dayStart = calendar.startOfDay(for: referenceDate)
        guard dayStart >= range.start, dayStart < range.end else { return nil }
        let intervalStart = max(session.startedAt, dayStart)
        let intervalEnd = min(session.pausedAt ?? referenceDate, referenceDate)
        let wallClockSeconds = max(0, intervalEnd.timeIntervalSince(intervalStart))
        let activeSeconds = min(
            max(0, session.activeDurationSeconds(at: referenceDate)),
            wallClockSeconds
        )
        guard intervalEnd > intervalStart, activeSeconds > 0 else { return nil }
        return (intervalStart, intervalEnd, activeSeconds)
    }
}

enum EstimateActualStats {
    static func points(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        outcomePoints: [OutcomeMixChartPoint],
        calendar: Calendar = .current
    ) -> [EstimateActualChartPoint] {
        guard !tasks.isEmpty, !outcomePoints.isEmpty else { return [] }

        let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let chartDays = Set(outcomePoints.map { calendar.startOfDay(for: $0.date) })
        var totalsByDay: [Date: (estimatedMinutes: Int, actualMinutes: Int, count: Int)] = [:]

        for log in logs {
            guard log.kind == .completed,
                  let timestamp = log.timestamp,
                  let task = tasksByID[log.taskID],
                  let estimatedMinutes = task.estimatedDurationMinutes else {
                continue
            }

            let day = calendar.startOfDay(for: timestamp)
            guard chartDays.contains(day),
                  let actualMinutes = actualDurationMinutes(for: log, task: task) else {
                continue
            }

            totalsByDay[day, default: (0, 0, 0)].estimatedMinutes += estimatedMinutes
            totalsByDay[day, default: (0, 0, 0)].actualMinutes += actualMinutes
            totalsByDay[day, default: (0, 0, 0)].count += 1
        }

        return outcomePoints.map { outcomePoint in
            let day = calendar.startOfDay(for: outcomePoint.date)
            let totals = totalsByDay[day, default: (0, 0, 0)]
            return EstimateActualChartPoint(
                date: outcomePoint.date,
                estimatedMinutes: totals.estimatedMinutes,
                actualMinutes: totals.actualMinutes,
                trackedCompletionCount: totals.count
            )
        }
    }

    static func totalEstimatedMinutes(in points: [EstimateActualChartPoint]) -> Int {
        points.reduce(0) { $0 + $1.estimatedMinutes }
    }

    static func totalActualMinutes(in points: [EstimateActualChartPoint]) -> Int {
        points.reduce(0) { $0 + $1.actualMinutes }
    }

    static func largestVarianceDay(in points: [EstimateActualChartPoint]) -> EstimateActualChartPoint? {
        points
            .filter { $0.hasTrackedTime && $0.absoluteDeltaMinutes > 0 }
            .max { lhs, rhs in
                if lhs.absoluteDeltaMinutes == rhs.absoluteDeltaMinutes {
                    return lhs.date > rhs.date
                }
                return lhs.absoluteDeltaMinutes < rhs.absoluteDeltaMinutes
            }
    }

    private static func actualDurationMinutes(for log: RoutineLog, task: RoutineTask) -> Int? {
        if let logActual = log.actualDurationMinutes {
            return logActual
        }

        guard task.isOneOffTask else { return nil }
        return task.actualDurationMinutes
    }
}
