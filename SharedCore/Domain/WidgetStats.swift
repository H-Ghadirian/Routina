import Foundation

struct WidgetStats: Codable, Sendable {
    let tasksDueToday: Int
    let completedToday: Int
    let completedThisWeek: Int
    let totalCompleted: Int
    let currentStreak: Int
    let lastUpdated: Date

    init(
        tasksDueToday: Int,
        completedToday: Int,
        completedThisWeek: Int,
        totalCompleted: Int,
        currentStreak: Int,
        lastUpdated: Date = .now
    ) {
        self.tasksDueToday = tasksDueToday
        self.completedToday = completedToday
        self.completedThisWeek = completedThisWeek
        self.totalCompleted = totalCompleted
        self.currentStreak = currentStreak
        self.lastUpdated = lastUpdated
    }

    static let placeholder = WidgetStats(
        tasksDueToday: 0,
        completedToday: 0,
        completedThisWeek: 0,
        totalCompleted: 0,
        currentStreak: 0
    )
}

enum WidgetStatsComputer {
    static func compute(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> WidgetStats {
        let completionTimestamps = logs
            .filter { $0.kind == .completed }
            .compactMap(\.timestamp)

        return WidgetStats(
            tasksDueToday: tasksDueToday(tasks: tasks, referenceDate: referenceDate, calendar: calendar),
            completedToday: completedToday(timestamps: completionTimestamps, referenceDate: referenceDate, calendar: calendar),
            completedThisWeek: completedThisWeek(timestamps: completionTimestamps, referenceDate: referenceDate, calendar: calendar),
            totalCompleted: completionTimestamps.count,
            currentStreak: currentStreak(timestamps: completionTimestamps, referenceDate: referenceDate, calendar: calendar),
            lastUpdated: referenceDate
        )
    }

    private static func tasksDueToday(
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        tasks.filter { task in
            RoutineDateMath.canMarkDone(for: task, referenceDate: referenceDate, calendar: calendar)
        }.count
    }

    private static func completedToday(
        timestamps: [Date],
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        timestamps.filter { calendar.isDate($0, inSameDayAs: referenceDate) }.count
    }

    private static func completedThisWeek(
        timestamps: [Date],
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: referenceDate)) else {
            return 0
        }
        return timestamps.filter { $0 >= weekAgo }.count
    }

    static func currentStreak(
        timestamps: [Date],
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        let completionDays = Set(timestamps.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: referenceDate)

        var day = today
        if !completionDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  completionDays.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while completionDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }
        return streak
    }
}
