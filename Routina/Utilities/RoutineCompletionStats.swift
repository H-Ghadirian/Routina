import Foundation

enum DoneChartRange: String, CaseIterable, Equatable, Identifiable {
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

enum RoutineCompletionStats {
    static func points(
        for range: DoneChartRange,
        timestamps: [Date],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [DoneChartPoint] {
        let endDate = calendar.startOfDay(for: referenceDate)
        guard let startDate = calendar.date(byAdding: .day, value: -(range.trailingDayCount - 1), to: endDate) else {
            return []
        }

        let countsByDay = timestamps.reduce(into: [Date: Int]()) { partialResult, timestamp in
            let day = calendar.startOfDay(for: timestamp)
            guard day >= startDate, day <= endDate else { return }
            partialResult[day, default: 0] += 1
        }

        return (0..<range.trailingDayCount).compactMap { dayOffset in
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
}
