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

    var id: Date { date }

    var minutes: Double {
        seconds / 60
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

enum FocusDurationStats {
    static func points(
        for range: DoneChartRange,
        sessions: [FocusSession],
        earliestActivityDate: Date? = nil,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [FocusDurationChartPoint] {
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

        let secondsByDay = sessions.reduce(into: [Date: TimeInterval]()) { partialResult, session in
            guard session.state == .completed else { return }
            let daySource = session.completedAt ?? session.startedAt
            guard let daySource else { return }
            let day = calendar.startOfDay(for: daySource)
            guard day >= startDate, day <= endDate else { return }
            partialResult[day, default: 0] += session.actualDurationSeconds
        }

        return (0..<dayCount).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                return nil
            }

            return FocusDurationChartPoint(
                date: date,
                seconds: secondsByDay[date, default: 0]
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
