import Foundation

enum FocusAchievementCategory: String, Equatable {
    case total
    case blocks
    case streak
    case session
    case daily
    case weekly
    case comeback
}

enum FocusAchievementUnit: Equatable {
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

struct FocusAchievementProgress: Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let category: FocusAchievementCategory
    let currentValue: Double
    let targetValue: Double
    let unit: FocusAchievementUnit

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

enum FocusAchievementStats {
    static func achievements(
        sessions: [FocusSession],
        calendar: Calendar = .current
    ) -> [FocusAchievementProgress] {
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
        let bestRollingWeekFocusDays = bestFocusDaysInRollingWeek(focusDays, calendar: calendar)
        let comebackQuietDays = longestQuietGapBeforeComeback(in: focusDays, calendar: calendar)

        return [
            FocusAchievementProgress(
                id: "focus.first",
                title: "First Focus",
                subtitle: "Complete your first focus session.",
                systemImage: "sparkles",
                category: .session,
                currentValue: Double(completedSessions.count),
                targetValue: 1,
                unit: .count(singular: "session", plural: "sessions")
            ),
            FocusAchievementProgress(
                id: "focus.blocks.100",
                title: "Block Builder",
                subtitle: "Earn 100 five-minute focus blocks.",
                systemImage: "square.grid.3x3.fill",
                category: .blocks,
                currentValue: Double(totalBlocks),
                targetValue: 100,
                unit: .count(singular: "block", plural: "blocks")
            ),
            FocusAchievementProgress(
                id: "focus.total.10h",
                title: "Ten-Hour Foundation",
                subtitle: "Reach 10 total hours of focus.",
                systemImage: "timer",
                category: .total,
                currentValue: totalSeconds,
                targetValue: 10 * 60 * 60,
                unit: .seconds
            ),
            FocusAchievementProgress(
                id: "focus.total.50h",
                title: "Deep Work Builder",
                subtitle: "Reach 50 total hours of focus.",
                systemImage: "clock.badge.checkmark.fill",
                category: .total,
                currentValue: totalSeconds,
                targetValue: 50 * 60 * 60,
                unit: .seconds
            ),
            FocusAchievementProgress(
                id: "focus.total.100h",
                title: "Focus Centurion",
                subtitle: "Reach 100 total hours of focus.",
                systemImage: "trophy.fill",
                category: .total,
                currentValue: totalSeconds,
                targetValue: 100 * 60 * 60,
                unit: .seconds
            ),
            FocusAchievementProgress(
                id: "focus.session.1h",
                title: "One-Hour Deep Dive",
                subtitle: "Complete a one-hour focus session.",
                systemImage: "stopwatch.fill",
                category: .session,
                currentValue: longestSessionSeconds,
                targetValue: 60 * 60,
                unit: .seconds
            ),
            FocusAchievementProgress(
                id: "focus.session.2h",
                title: "Two-Hour Flow",
                subtitle: "Complete a two-hour focus session.",
                systemImage: "hourglass",
                category: .session,
                currentValue: longestSessionSeconds,
                targetValue: 2 * 60 * 60,
                unit: .seconds
            ),
            FocusAchievementProgress(
                id: "focus.day.2h",
                title: "Strong Focus Day",
                subtitle: "Log two hours of focus in one day.",
                systemImage: "sun.max.fill",
                category: .daily,
                currentValue: bestDailyFocusSeconds,
                targetValue: 2 * 60 * 60,
                unit: .seconds
            ),
            FocusAchievementProgress(
                id: "focus.day.4h",
                title: "Protected Day",
                subtitle: "Log four hours of focus in one day.",
                systemImage: "shield.lefthalf.filled",
                category: .daily,
                currentValue: bestDailyFocusSeconds,
                targetValue: 4 * 60 * 60,
                unit: .seconds
            ),
            FocusAchievementProgress(
                id: "focus.streak.5d",
                title: "Five-Day Thread",
                subtitle: "Focus on five days in a row.",
                systemImage: "flame.fill",
                category: .streak,
                currentValue: Double(longestStreakDays),
                targetValue: 5,
                unit: .count(singular: "day", plural: "days")
            ),
            FocusAchievementProgress(
                id: "focus.streak.14d",
                title: "Two-Week Rhythm",
                subtitle: "Focus on 14 days in a row.",
                systemImage: "calendar.badge.checkmark",
                category: .streak,
                currentValue: Double(longestStreakDays),
                targetValue: 14,
                unit: .count(singular: "day", plural: "days")
            ),
            FocusAchievementProgress(
                id: "focus.streak.30d",
                title: "Monthly Anchor",
                subtitle: "Focus on 30 days in a row.",
                systemImage: "calendar.circle.fill",
                category: .streak,
                currentValue: Double(longestStreakDays),
                targetValue: 30,
                unit: .count(singular: "day", plural: "days")
            ),
            FocusAchievementProgress(
                id: "focus.week.5d",
                title: "Steady Week",
                subtitle: "Focus on five days inside any seven-day span.",
                systemImage: "calendar.day.timeline.left",
                category: .weekly,
                currentValue: Double(bestRollingWeekFocusDays),
                targetValue: 5,
                unit: .count(singular: "day", plural: "days")
            ),
            FocusAchievementProgress(
                id: "focus.comeback.7d",
                title: "Comeback Focus",
                subtitle: "Return to focus after seven quiet days.",
                systemImage: "arrow.uturn.forward.circle.fill",
                category: .comeback,
                currentValue: Double(comebackQuietDays),
                targetValue: 7,
                unit: .count(singular: "quiet day", plural: "quiet days")
            ),
        ]
    }

    static func earnedCount(in achievements: [FocusAchievementProgress]) -> Int {
        achievements.filter(\.isEarned).count
    }

    static func displayOrdered(_ achievements: [FocusAchievementProgress]) -> [FocusAchievementProgress] {
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

    private static func focusSecondsByDay(
        sessions: [FocusSession],
        calendar: Calendar
    ) -> [Date: TimeInterval] {
        sessions.reduce(into: [Date: TimeInterval]()) { partialResult, session in
            guard let daySource = session.completedAt ?? session.startedAt else { return }
            partialResult[calendar.startOfDay(for: daySource), default: 0] += session.actualDurationSeconds
        }
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

    private static func bestFocusDaysInRollingWeek(
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
