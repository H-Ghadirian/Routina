import Foundation

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
                !logs.isEmpty
            else {
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
        let canonicalFocusSessions = FocusStatsSessionCanonicalization.canonicalTaskSessions(
            focusSessions
        )
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
                chartDays.contains(calendar.startOfDay(for: timestamp))
            else {
                continue
            }

            for goalID in activeGoalIDsByTaskID[log.taskID, default: []] {
                completedTaskIDsByGoalID[goalID, default: []].insert(log.taskID)
                completionCountsByGoalID[goalID, default: 0] += 1
            }
        }

        var focusSecondsByGoalID: [UUID: TimeInterval] = [:]
        for session in canonicalFocusSessions {
            guard session.state == .completed,
                let daySource = session.completedAt ?? session.startedAt,
                chartDays.contains(calendar.startOfDay(for: daySource))
            else {
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
                let estimatedMinutes = task.estimatedDurationMinutes
            else {
                continue
            }

            let day = calendar.startOfDay(for: timestamp)
            guard chartDays.contains(day),
                let actualMinutes = actualDurationMinutes(for: log, task: task)
            else {
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
