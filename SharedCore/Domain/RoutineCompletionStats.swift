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
            if taskID == FocusSession.unassignedTaskID {
                title = "Unassigned focus"
            } else {
                title = taskTitlesByID[taskID] ?? "Unknown task"
            }

            let key: String
            let contributionTaskID: UUID?
            if taskID == FocusSession.unassignedTaskID {
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
        for session in focusSessions where session.state == .completed {
            allocateFocusSession(
                session,
                into: &focusSecondsByHour,
                range: range,
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

    private static func allocateFocusSession(
        _ session: FocusSession,
        into focusSecondsByHour: inout [Int: TimeInterval],
        range: (start: Date, end: Date),
        calendar: Calendar
    ) {
        guard let startedAt = session.startedAt,
              let completedAt = session.completedAt,
              completedAt > startedAt else {
            return
        }

        var cursor = max(startedAt, range.start)
        let clampedEnd = min(completedAt, range.end)
        guard clampedEnd > cursor else { return }

        while cursor < clampedEnd {
            let hour = calendar.component(.hour, from: cursor)
            let hourEnd = calendar.dateInterval(of: .hour, for: cursor)?.end ?? clampedEnd
            let segmentEnd = min(hourEnd, clampedEnd)
            guard segmentEnd > cursor else { break }

            focusSecondsByHour[hour, default: 0] += segmentEnd.timeIntervalSince(cursor)
            cursor = segmentEnd
        }
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
