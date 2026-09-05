import Foundation

struct DoneChartRange: Equatable, Identifiable, Codable, Sendable, Hashable {
    enum Kind: String, Codable, Sendable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case custom = "Custom"
    }

    static let today = Self(kind: .today)
    static let week = Self(kind: .week)
    static let month = Self(kind: .month)
    static let year = Self(kind: .year)
    static let allCases: [Self] = [.today, .week, .month, .year]

    let kind: Kind
    let customStart: Date?
    let customEnd: Date?

    private init(kind: Kind, customStart: Date? = nil, customEnd: Date? = nil) {
        self.kind = kind
        self.customStart = customStart
        self.customEnd = customEnd
    }

    static func custom(from start: Date, through end: Date, calendar: Calendar = .current) -> Self {
        let first = calendar.startOfDay(for: min(start, end))
        let last = calendar.startOfDay(for: max(start, end))
        return Self(kind: .custom, customStart: first, customEnd: last)
    }

    var id: String {
        "\(kind.rawValue)-\(customStart?.timeIntervalSinceReferenceDate ?? 0)-\(customEnd?.timeIntervalSinceReferenceDate ?? 0)"
    }

    var rawValue: String { kind.rawValue }

    var trailingDayCount: Int {
        if kind == .custom, let customStart, let customEnd {
            return max(Calendar.current.dateComponents([.day], from: customStart, to: customEnd).day ?? 0, 0) + 1
        }
        switch kind {
        case .today:
            return 1
        case .week:
            return 7
        case .month:
            return 30
        case .year:
            return 365
        case .custom:
            return 1
        }
    }

    var periodDescription: String {
        switch kind {
        case .today:
            return "Today"
        case .week:
            return "Last 7 days"
        case .month:
            return "Last 30 days"
        case .year:
            return "Last 365 days"
        case .custom:
            guard let customStart, let customEnd else { return "Custom range" }
            return
                "\(customStart.formatted(date: .abbreviated, time: .omitted)) – \(customEnd.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    func referenceDate(relativeTo fallback: Date) -> Date {
        customEnd ?? fallback
    }

    func startDate(relativeTo fallback: Date, calendar: Calendar) -> Date {
        if let customStart { return calendar.startOfDay(for: customStart) }
        let end = calendar.startOfDay(for: referenceDate(relativeTo: fallback))
        return calendar.date(byAdding: .day, value: -(trailingDayCount - 1), to: end) ?? end
    }

    private enum CodingKeys: String, CodingKey { case kind, customStart, customEnd }

    init(from decoder: Decoder) throws {
        if let legacy = try? decoder.singleValueContainer().decode(String.self),
            let kind = Kind(rawValue: legacy)
        {
            self.init(kind: kind)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try container.decode(Kind.self, forKey: .kind),
            customStart: try container.decodeIfPresent(Date.self, forKey: .customStart),
            customEnd: try container.decodeIfPresent(Date.self, forKey: .customEnd)
        )
    }

    func encode(to encoder: Encoder) throws {
        if kind != .custom {
            var container = encoder.singleValueContainer()
            try container.encode(kind.rawValue)
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(customStart, forKey: .customStart)
        try container.encodeIfPresent(customEnd, forKey: .customEnd)
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
                chartDays.contains(calendar.startOfDay(for: timestamp))
            else {
                return
            }

            partialResult[log.taskID, default: 0] += 1
        }

        let summaries = RoutineTagColors.applying(
            tagColors,
            to: RoutineTag.summaries(from: tasks, countsByTaskID: completionCountsByTaskID)
        )

        return
            summaries
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
