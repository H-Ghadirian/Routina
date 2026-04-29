import Foundation

enum DoneChartRange: String, CaseIterable, Equatable, Identifiable, Codable, Sendable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: Self { self }

    var trailingDayCount: Int {
        switch self {
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

struct FocusDurationChartPoint: Equatable, Identifiable {
    let date: Date
    let seconds: TimeInterval

    var id: Date { date }

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

enum RoutineCompletionStats {
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

    static func busiestDay(in points: [FocusDurationChartPoint]) -> FocusDurationChartPoint? {
        points.max { lhs, rhs in
            if lhs.seconds == rhs.seconds {
                return lhs.date > rhs.date
            }
            return lhs.seconds < rhs.seconds
        }
    }
}
