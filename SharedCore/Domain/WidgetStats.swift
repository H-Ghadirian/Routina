import Foundation

struct WidgetStats: Codable, Sendable {
    let tasksDueToday: Int
    let completedToday: Int
    let completedThisWeek: Int
    let totalCompleted: Int
    let currentStreak: Int
    let focusSecondsToday: TimeInterval
    let focusSessionsToday: Int
    let activeFocusIncrementStartedAt: Date?
    let lastUpdated: Date

    init(
        tasksDueToday: Int,
        completedToday: Int,
        completedThisWeek: Int,
        totalCompleted: Int,
        currentStreak: Int,
        focusSecondsToday: TimeInterval = 0,
        focusSessionsToday: Int = 0,
        activeFocusIncrementStartedAt: Date? = nil,
        lastUpdated: Date = .now
    ) {
        self.tasksDueToday = tasksDueToday
        self.completedToday = completedToday
        self.completedThisWeek = completedThisWeek
        self.totalCompleted = totalCompleted
        self.currentStreak = currentStreak
        self.focusSecondsToday = max(0, focusSecondsToday)
        self.focusSessionsToday = max(0, focusSessionsToday)
        self.activeFocusIncrementStartedAt = activeFocusIncrementStartedAt
        self.lastUpdated = lastUpdated
    }

    var hasActiveFocusToday: Bool {
        activeFocusIncrementStartedAt != nil
    }

    func focusSecondsToday(at date: Date = .now) -> TimeInterval {
        guard let activeFocusIncrementStartedAt else {
            return focusSecondsToday
        }

        return max(0, focusSecondsToday + date.timeIntervalSince(activeFocusIncrementStartedAt))
    }

    static let placeholder = WidgetStats(
        tasksDueToday: 0,
        completedToday: 0,
        completedThisWeek: 0,
        totalCompleted: 0,
        currentStreak: 0
    )

    private enum CodingKeys: String, CodingKey {
        case tasksDueToday
        case completedToday
        case completedThisWeek
        case totalCompleted
        case currentStreak
        case focusSecondsToday
        case focusSessionsToday
        case activeFocusIncrementStartedAt
        case lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasksDueToday = try container.decode(Int.self, forKey: .tasksDueToday)
        completedToday = try container.decode(Int.self, forKey: .completedToday)
        completedThisWeek = try container.decode(Int.self, forKey: .completedThisWeek)
        totalCompleted = try container.decode(Int.self, forKey: .totalCompleted)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        focusSecondsToday = try container.decodeIfPresent(TimeInterval.self, forKey: .focusSecondsToday) ?? 0
        focusSessionsToday = try container.decodeIfPresent(Int.self, forKey: .focusSessionsToday) ?? 0
        activeFocusIncrementStartedAt = try container.decodeIfPresent(Date.self, forKey: .activeFocusIncrementStartedAt)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }
}

enum WidgetStatsComputer {
    static func compute(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession] = [],
        sprintFocusSessions: [SprintFocusSessionRecord] = [],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> WidgetStats {
        let completionTimestamps = logs
            .filter { $0.kind == .completed }
            .compactMap(\.timestamp)
        let focusSummary = todayFocusSummary(
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
            referenceDate: referenceDate,
            calendar: calendar
        )

        return WidgetStats(
            tasksDueToday: tasksDueToday(tasks: tasks, referenceDate: referenceDate, calendar: calendar),
            completedToday: completedToday(timestamps: completionTimestamps, referenceDate: referenceDate, calendar: calendar),
            completedThisWeek: completedThisWeek(timestamps: completionTimestamps, referenceDate: referenceDate, calendar: calendar),
            totalCompleted: completionTimestamps.count,
            currentStreak: currentStreak(timestamps: completionTimestamps, referenceDate: referenceDate, calendar: calendar),
            focusSecondsToday: focusSummary.seconds,
            focusSessionsToday: focusSummary.sessionCount,
            activeFocusIncrementStartedAt: focusSummary.hasIncrementingFocus ? referenceDate : nil,
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

    private struct TodayFocusSummary {
        var seconds: TimeInterval = 0
        var sessionCount = 0
        var hasIncrementingFocus = false

        mutating func add(seconds: TimeInterval, isIncrementing: Bool = false) {
            let clampedSeconds = max(0, seconds)
            if clampedSeconds > 0 || isIncrementing {
                self.seconds += clampedSeconds
                sessionCount += 1
            }
            hasIncrementingFocus = hasIncrementingFocus || isIncrementing
        }
    }

    private static func todayFocusSummary(
        focusSessions: [FocusSession],
        sprintFocusSessions: [SprintFocusSessionRecord],
        referenceDate: Date,
        calendar: Calendar
    ) -> TodayFocusSummary {
        var summary = TodayFocusSummary()

        for session in focusSessions {
            switch session.state {
            case .completed:
                summary.add(
                    seconds: focusSecondsOnReferenceDay(
                        startedAt: session.startedAt,
                        endedAt: session.completedAt,
                        activeSeconds: session.actualDurationSeconds,
                        referenceDate: referenceDate,
                        calendar: calendar
                    )
                )
            case .active:
                guard sessionTouchesReferenceDay(
                    startedAt: session.startedAt,
                    endedAt: nil,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) else {
                    continue
                }
                summary.add(
                    seconds: focusSecondsOnReferenceDay(
                        startedAt: session.startedAt,
                        endedAt: min(session.pausedAt ?? referenceDate, referenceDate),
                        activeSeconds: session.activeDurationSeconds(at: referenceDate),
                        referenceDate: referenceDate,
                        calendar: calendar
                    ),
                    isIncrementing: !session.isPaused
                )
            case .abandoned:
                continue
            }
        }

        for session in sprintFocusSessions {
            if let stoppedAt = session.stoppedAt {
                summary.add(
                    seconds: focusSecondsOnReferenceDay(
                        startedAt: session.startedAt,
                        endedAt: stoppedAt,
                        activeSeconds: session.activeDurationSeconds(at: referenceDate),
                        referenceDate: referenceDate,
                        calendar: calendar
                    )
                )
            } else {
                guard sessionTouchesReferenceDay(
                    startedAt: session.startedAt,
                    endedAt: nil,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) else {
                    continue
                }
                summary.add(
                    seconds: focusSecondsOnReferenceDay(
                        startedAt: session.startedAt,
                        endedAt: min(session.pausedAt ?? referenceDate, referenceDate),
                        activeSeconds: session.activeDurationSeconds(at: referenceDate),
                        referenceDate: referenceDate,
                        calendar: calendar
                    ),
                    isIncrementing: !session.isPaused
                )
            }
        }

        return summary
    }

    private static func focusSecondsOnReferenceDay(
        startedAt: Date?,
        endedAt: Date?,
        activeSeconds: TimeInterval,
        referenceDate: Date,
        calendar: Calendar
    ) -> TimeInterval {
        guard let startedAt,
              sessionTouchesReferenceDay(
                  startedAt: startedAt,
                  endedAt: endedAt,
                  referenceDate: referenceDate,
                  calendar: calendar
              ) else {
            return 0
        }

        let dayStart = calendar.startOfDay(for: referenceDate)
        let dayRangeStart = max(startedAt, dayStart)
        let dayRangeEnd = min(endedAt ?? referenceDate, referenceDate)
        let wallClockSecondsOnDay = max(0, dayRangeEnd.timeIntervalSince(dayRangeStart))
        return min(max(0, activeSeconds), wallClockSecondsOnDay)
    }

    private static func sessionTouchesReferenceDay(
        startedAt: Date?,
        endedAt: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let startedAt, startedAt <= referenceDate else { return false }
        let dayStart = calendar.startOfDay(for: referenceDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return calendar.isDate(startedAt, inSameDayAs: referenceDate)
        }
        return startedAt < dayEnd && (endedAt ?? referenceDate) >= dayStart
    }
}
