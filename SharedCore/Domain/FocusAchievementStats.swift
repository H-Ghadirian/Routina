import Foundation

enum StatsAchievementCategory: String, Equatable {
    case total
    case blocks
    case streak
    case session
    case daily
    case weekly
    case comeback
    case sleep
    case sleepStreak
    case away
    case done
    case doneStreak
}

enum StatsAchievementDomain: String, CaseIterable, Equatable, Identifiable {
    case all
    case focus
    case sleep
    case away
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .focus:
            return "Focus"
        case .sleep:
            return "Sleep"
        case .away:
            return "Away"
        case .done:
            return "Done"
        }
    }
}

enum StatsAchievementUnit: Equatable {
    case seconds
    case count(singular: String, plural: String)

    func text(for value: Double) -> String {
        switch self {
        case .seconds:
            return Self.durationText(seconds: value)
        case let .count(singular, plural):
            let count = max(0, Int(value.rounded(.down)))
            return "\(count.formatted()) \(count == 1 ? singular : plural)"
        }
    }

    private static func durationText(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded(.down)))
        guard totalMinutes > 0 else { return "0m" }

        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        guard minutes > 0 else { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}

struct StatsAchievementProgress: Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let domain: StatsAchievementDomain
    let category: StatsAchievementCategory
    let currentValue: Double
    let targetValue: Double
    let unit: StatsAchievementUnit

    var isEarned: Bool {
        currentValue >= targetValue
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(max(currentValue / targetValue, 0), 1)
    }

    var progressText: String {
        "\(unit.text(for: currentValue)) / \(unit.text(for: targetValue))"
    }
}

enum StatsAchievementStats {
    static func achievements(
        focusSessions: [FocusSession],
        sleepSessions: [SleepSession] = [],
        awaySessions: [AwaySession] = [],
        logs: [RoutineLog] = [],
        calendar: Calendar = .current
    ) -> [StatsAchievementProgress] {
        focusAchievements(sessions: focusSessions, calendar: calendar)
            + sleepAchievements(sessions: sleepSessions, calendar: calendar)
            + awayAchievements(sessions: awaySessions, calendar: calendar)
            + doneAchievements(logs: logs, calendar: calendar)
    }

    static func achievements(
        sessions: [FocusSession],
        calendar: Calendar = .current
    ) -> [StatsAchievementProgress] {
        focusAchievements(sessions: sessions, calendar: calendar)
    }

    static func earnedCount(in achievements: [StatsAchievementProgress]) -> Int {
        achievements.filter(\.isEarned).count
    }

    static func displayOrdered(_ achievements: [StatsAchievementProgress]) -> [StatsAchievementProgress] {
        achievements
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isEarned != rhs.element.isEarned {
                    return !lhs.element.isEarned
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func focusAchievements(
        sessions: [FocusSession],
        calendar: Calendar
    ) -> [StatsAchievementProgress] {
        let completedSessions = sessions.filter { $0.state == .completed }
        let totalSeconds = completedSessions.reduce(0) { $0 + $1.actualDurationSeconds }
        let totalBlocks = completedSessions.reduce(0) {
            $0 + FocusBlockProgress.filledBlockCount(for: $1.actualDurationSeconds)
        }
        let longestSessionSeconds = completedSessions.map(\.actualDurationSeconds).max() ?? 0
        let dailyFocusSeconds = focusSecondsByDay(sessions: completedSessions, calendar: calendar)
        let bestDailyFocusSeconds = dailyFocusSeconds.values.max() ?? 0
        let focusDays = dailyFocusSeconds.keys.sorted()
        let longestStreakDays = longestStreak(in: focusDays, calendar: calendar)
        let bestRollingWeekFocusDays = bestActiveDaysInRollingWeek(focusDays, calendar: calendar)
        let comebackQuietDays = longestQuietGapBeforeComeback(in: focusDays, calendar: calendar)

        return [
            StatsAchievementProgress(
                id: "focus.first",
                title: "First Focus",
                subtitle: "Complete your first focus session.",
                systemImage: "sparkles",
                domain: .focus,
                category: .session,
                currentValue: Double(completedSessions.count),
                targetValue: 1,
                unit: .count(singular: "session", plural: "sessions")
            ),
            StatsAchievementProgress(
                id: "focus.blocks.100",
                title: "Block Builder",
                subtitle: "Earn 100 five-minute focus blocks.",
                systemImage: "square.grid.3x3.fill",
                domain: .focus,
                category: .blocks,
                currentValue: Double(totalBlocks),
                targetValue: 100,
                unit: .count(singular: "block", plural: "blocks")
            ),
            StatsAchievementProgress(
                id: "focus.total.10h",
                title: "Ten-Hour Foundation",
                subtitle: "Reach 10 total hours of focus.",
                systemImage: "timer",
                domain: .focus,
                category: .total,
                currentValue: totalSeconds,
                targetValue: 10 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "focus.total.50h",
                title: "Deep Work Builder",
                subtitle: "Reach 50 total hours of focus.",
                systemImage: "clock.badge.checkmark.fill",
                domain: .focus,
                category: .total,
                currentValue: totalSeconds,
                targetValue: 50 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "focus.total.100h",
                title: "Focus Centurion",
                subtitle: "Reach 100 total hours of focus.",
                systemImage: "trophy.fill",
                domain: .focus,
                category: .total,
                currentValue: totalSeconds,
                targetValue: 100 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "focus.session.1h",
                title: "One-Hour Deep Dive",
                subtitle: "Complete a one-hour focus session.",
                systemImage: "stopwatch.fill",
                domain: .focus,
                category: .session,
                currentValue: longestSessionSeconds,
                targetValue: 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "focus.session.2h",
                title: "Two-Hour Flow",
                subtitle: "Complete a two-hour focus session.",
                systemImage: "hourglass",
                domain: .focus,
                category: .session,
                currentValue: longestSessionSeconds,
                targetValue: 2 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "focus.day.2h",
                title: "Strong Focus Day",
                subtitle: "Log two hours of focus in one day.",
                systemImage: "sun.max.fill",
                domain: .focus,
                category: .daily,
                currentValue: bestDailyFocusSeconds,
                targetValue: 2 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "focus.day.4h",
                title: "Protected Day",
                subtitle: "Log four hours of focus in one day.",
                systemImage: "shield.lefthalf.filled",
                domain: .focus,
                category: .daily,
                currentValue: bestDailyFocusSeconds,
                targetValue: 4 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "focus.streak.5d",
                title: "Five-Day Thread",
                subtitle: "Focus on five days in a row.",
                systemImage: "flame.fill",
                domain: .focus,
                category: .streak,
                currentValue: Double(longestStreakDays),
                targetValue: 5,
                unit: .count(singular: "day", plural: "days")
            ),
            StatsAchievementProgress(
                id: "focus.streak.14d",
                title: "Two-Week Rhythm",
                subtitle: "Focus on 14 days in a row.",
                systemImage: "calendar.badge.checkmark",
                domain: .focus,
                category: .streak,
                currentValue: Double(longestStreakDays),
                targetValue: 14,
                unit: .count(singular: "day", plural: "days")
            ),
            StatsAchievementProgress(
                id: "focus.streak.30d",
                title: "Monthly Anchor",
                subtitle: "Focus on 30 days in a row.",
                systemImage: "calendar.circle.fill",
                domain: .focus,
                category: .streak,
                currentValue: Double(longestStreakDays),
                targetValue: 30,
                unit: .count(singular: "day", plural: "days")
            ),
            StatsAchievementProgress(
                id: "focus.week.5d",
                title: "Steady Week",
                subtitle: "Focus on five days inside any seven-day span.",
                systemImage: "calendar.day.timeline.left",
                domain: .focus,
                category: .weekly,
                currentValue: Double(bestRollingWeekFocusDays),
                targetValue: 5,
                unit: .count(singular: "day", plural: "days")
            ),
            StatsAchievementProgress(
                id: "focus.comeback.7d",
                title: "Comeback Focus",
                subtitle: "Return to focus after seven quiet days.",
                systemImage: "arrow.uturn.forward.circle.fill",
                domain: .focus,
                category: .comeback,
                currentValue: Double(comebackQuietDays),
                targetValue: 7,
                unit: .count(singular: "quiet day", plural: "quiet days")
            ),
        ]
    }

    private static func sleepAchievements(
        sessions: [SleepSession],
        calendar: Calendar
    ) -> [StatsAchievementProgress] {
        let completedSessions = sessions.filter { !$0.isActive }
        let totalSeconds = completedSessions.reduce(0) { total, session in
            total + session.durationSeconds()
        }
        let longestSleepSeconds = completedSessions
            .map { $0.durationSeconds() }
            .max() ?? 0
        let sleepDays = uniqueDays(
            dates: completedSessions.compactMap { $0.startedAt ?? $0.endedAt },
            calendar: calendar
        )
        let longestSleepStreakDays = longestStreak(in: sleepDays, calendar: calendar)

        return [
            StatsAchievementProgress(
                id: "sleep.first",
                title: "First Sleep",
                subtitle: "Finish your first sleep session.",
                systemImage: "bed.double.fill",
                domain: .sleep,
                category: .sleep,
                currentValue: Double(completedSessions.count),
                targetValue: 1,
                unit: .count(singular: "session", plural: "sessions")
            ),
            StatsAchievementProgress(
                id: "sleep.total.56h",
                title: "Sleep Bank",
                subtitle: "Record 56 total hours of sleep.",
                systemImage: "moon.zzz.fill",
                domain: .sleep,
                category: .sleep,
                currentValue: totalSeconds,
                targetValue: 56 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "sleep.session.7h",
                title: "Seven-Hour Stretch",
                subtitle: "Finish a sleep session lasting seven hours.",
                systemImage: "moon.stars.fill",
                domain: .sleep,
                category: .sleep,
                currentValue: longestSleepSeconds,
                targetValue: 7 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "sleep.streak.7d",
                title: "Week of Sleep",
                subtitle: "Record sleep on seven days in a row.",
                systemImage: "calendar.badge.clock",
                domain: .sleep,
                category: .sleepStreak,
                currentValue: Double(longestSleepStreakDays),
                targetValue: 7,
                unit: .count(singular: "day", plural: "days")
            ),
        ]
    }

    private static func awayAchievements(
        sessions: [AwaySession],
        calendar: Calendar
    ) -> [StatsAchievementProgress] {
        let finishedSessions = sessions.filter { !$0.isActive }
        let completedSessions = finishedSessions.filter { $0.state == .completed }
        let totalSeconds = finishedSessions.reduce(0) { total, session in
            total + session.durationSeconds()
        }
        let awayDays = uniqueDays(
            dates: finishedSessions.compactMap { $0.startedAt ?? $0.finishedAt },
            calendar: calendar
        )

        return [
            StatsAchievementProgress(
                id: "away.first",
                title: "First Away",
                subtitle: "Finish your first Away session.",
                systemImage: "lock.shield.fill",
                domain: .away,
                category: .away,
                currentValue: Double(finishedSessions.count),
                targetValue: 1,
                unit: .count(singular: "session", plural: "sessions")
            ),
            StatsAchievementProgress(
                id: "away.total.5h",
                title: "Protected Hours",
                subtitle: "Record five total hours in Away sessions.",
                systemImage: "shield.checkered",
                domain: .away,
                category: .away,
                currentValue: totalSeconds,
                targetValue: 5 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress(
                id: "away.sessions.10",
                title: "Ten True Breaks",
                subtitle: "Finish ten Away sessions.",
                systemImage: "figure.walk.circle.fill",
                domain: .away,
                category: .away,
                currentValue: Double(finishedSessions.count),
                targetValue: 10,
                unit: .count(singular: "session", plural: "sessions")
            ),
            StatsAchievementProgress(
                id: "away.completed.5",
                title: "Stay the Course",
                subtitle: "Complete five Away sessions for their planned duration.",
                systemImage: "checkmark.shield.fill",
                domain: .away,
                category: .away,
                currentValue: Double(completedSessions.count),
                targetValue: 5,
                unit: .count(singular: "session", plural: "sessions")
            ),
            StatsAchievementProgress(
                id: "away.days.5",
                title: "Away Week",
                subtitle: "Use Away on five different days.",
                systemImage: "calendar.day.timeline.left",
                domain: .away,
                category: .away,
                currentValue: Double(awayDays.count),
                targetValue: 5,
                unit: .count(singular: "day", plural: "days")
            ),
        ]
    }

    private static func doneAchievements(
        logs: [RoutineLog],
        calendar: Calendar
    ) -> [StatsAchievementProgress] {
        let completedLogs = logs.filter { $0.kind == .completed }
        let completedDays = uniqueDays(
            dates: completedLogs.compactMap(\.timestamp),
            calendar: calendar
        )
        let doneCountsByDay = completedLogs.reduce(into: [Date: Int]()) { partialResult, log in
            guard let timestamp = log.timestamp else { return }
            partialResult[calendar.startOfDay(for: timestamp), default: 0] += 1
        }
        let bestDailyDoneCount = doneCountsByDay.values.max() ?? 0
        let longestDoneStreakDays = longestStreak(in: completedDays, calendar: calendar)
        let bestRollingWeekDoneDays = bestActiveDaysInRollingWeek(completedDays, calendar: calendar)

        return [
            StatsAchievementProgress(
                id: "done.first",
                title: "First Done",
                subtitle: "Mark your first task done.",
                systemImage: "checkmark.seal.fill",
                domain: .done,
                category: .done,
                currentValue: Double(completedLogs.count),
                targetValue: 1,
                unit: .count(singular: "done", plural: "done")
            ),
            StatsAchievementProgress(
                id: "done.total.100",
                title: "Century of Done",
                subtitle: "Mark 100 tasks done.",
                systemImage: "trophy.fill",
                domain: .done,
                category: .done,
                currentValue: Double(completedLogs.count),
                targetValue: 100,
                unit: .count(singular: "done", plural: "done")
            ),
            StatsAchievementProgress(
                id: "done.day.5",
                title: "Five-Done Day",
                subtitle: "Mark five tasks done in one day.",
                systemImage: "5.circle.fill",
                domain: .done,
                category: .done,
                currentValue: Double(bestDailyDoneCount),
                targetValue: 5,
                unit: .count(singular: "done", plural: "done")
            ),
            StatsAchievementProgress(
                id: "done.streak.7d",
                title: "Seven-Day Done Streak",
                subtitle: "Mark something done on seven days in a row.",
                systemImage: "flame.fill",
                domain: .done,
                category: .doneStreak,
                currentValue: Double(longestDoneStreakDays),
                targetValue: 7,
                unit: .count(singular: "day", plural: "days")
            ),
            StatsAchievementProgress(
                id: "done.week.5d",
                title: "Steady Done Week",
                subtitle: "Mark work done on five days inside any seven-day span.",
                systemImage: "calendar.day.timeline.left",
                domain: .done,
                category: .doneStreak,
                currentValue: Double(bestRollingWeekDoneDays),
                targetValue: 5,
                unit: .count(singular: "day", plural: "days")
            ),
        ]
    }

    private static func focusSecondsByDay(
        sessions: [FocusSession],
        calendar: Calendar
    ) -> [Date: TimeInterval] {
        sessions.reduce(into: [Date: TimeInterval]()) { partialResult, session in
            guard let daySource = session.completedAt ?? session.startedAt else { return }
            partialResult[calendar.startOfDay(for: daySource), default: 0] += session.actualDurationSeconds
        }
    }

    private static func uniqueDays(
        dates: [Date],
        calendar: Calendar
    ) -> [Date] {
        Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted()
    }

    private static func longestStreak(
        in sortedDays: [Date],
        calendar: Calendar
    ) -> Int {
        guard !sortedDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for index in sortedDays.indices.dropFirst() {
            let dayGap = calendar.dateComponents([.day], from: sortedDays[index - 1], to: sortedDays[index]).day ?? 0
            if dayGap == 1 {
                current += 1
            } else if dayGap > 1 {
                current = 1
            }
            longest = max(longest, current)
        }

        return longest
    }

    private static func bestActiveDaysInRollingWeek(
        _ sortedDays: [Date],
        calendar: Calendar
    ) -> Int {
        guard !sortedDays.isEmpty else { return 0 }

        var best = 1
        var windowStartIndex = 0

        for windowEndIndex in sortedDays.indices {
            while windowStartIndex < windowEndIndex {
                let daySpan = calendar.dateComponents(
                    [.day],
                    from: sortedDays[windowStartIndex],
                    to: sortedDays[windowEndIndex]
                ).day ?? 0
                guard daySpan > 6 else { break }
                windowStartIndex += 1
            }

            best = max(best, windowEndIndex - windowStartIndex + 1)
        }

        return best
    }

    private static func longestQuietGapBeforeComeback(
        in sortedDays: [Date],
        calendar: Calendar
    ) -> Int {
        guard sortedDays.count > 1 else { return 0 }

        return sortedDays.indices.dropFirst().reduce(0) { bestGap, index in
            let dayGap = calendar.dateComponents([.day], from: sortedDays[index - 1], to: sortedDays[index]).day ?? 0
            return max(bestGap, max(0, dayGap - 1))
        }
    }
}

typealias FocusAchievementCategory = StatsAchievementCategory
typealias FocusAchievementUnit = StatsAchievementUnit
typealias FocusAchievementProgress = StatsAchievementProgress
typealias FocusAchievementStats = StatsAchievementStats
