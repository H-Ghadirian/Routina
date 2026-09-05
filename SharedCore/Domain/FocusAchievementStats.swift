import Foundation

enum StatsAchievementStats {
    static func achievements(
        focusSessions: [FocusSession],
        sleepSessions: [SleepSession] = [],
        awaySessions: [AwaySession] = [],
        logs: [RoutineLog] = [],
        emotionLogs: [EmotionLog] = [],
        notes: [RoutineNote] = [],
        noteAttachmentNoteIDs: Set<UUID> = [],
        goals: [RoutineGoal] = [],
        places: [RoutinePlace] = [],
        placeCheckInSessions: [PlaceCheckInSession] = [],
        calendar: Calendar = .current
    ) -> [StatsAchievementProgress] {
        let includesPlaces = !places.isEmpty || !placeCheckInSessions.isEmpty

        return focusAchievements(sessions: focusSessions, calendar: calendar)
            + sleepAchievements(sessions: sleepSessions, calendar: calendar)
            + awayAchievements(sessions: awaySessions, calendar: calendar)
            + doneAchievements(logs: logs, calendar: calendar)
            + emotionAchievements(
                logs: emotionLogs,
                calendar: calendar,
                includingPlaces: includesPlaces
            )
            + (includesPlaces ? placeAchievements(
                places: places,
                sessions: placeCheckInSessions,
                calendar: calendar
            ) : [])
            + goalAchievements(goals: goals)
            + noteAchievements(
                notes: notes,
                noteAttachmentNoteIDs: noteAttachmentNoteIDs,
                calendar: calendar
            )
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
            StatsAchievementProgress.catalogued(
                id: "focus.first",
                systemImage: "sparkles",
                domain: .focus,
                category: .session,
                currentValue: Double(completedSessions.count),
                targetValue: 1,
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.blocks.100",
                systemImage: "square.grid.3x3.fill",
                domain: .focus,
                category: .blocks,
                currentValue: Double(totalBlocks),
                targetValue: 100,
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.total.10h",
                systemImage: "timer",
                domain: .focus,
                category: .total,
                currentValue: totalSeconds,
                targetValue: 10 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.total.50h",
                systemImage: "clock.badge.checkmark.fill",
                domain: .focus,
                category: .total,
                currentValue: totalSeconds,
                targetValue: 50 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.total.100h",
                systemImage: "trophy.fill",
                domain: .focus,
                category: .total,
                currentValue: totalSeconds,
                targetValue: 100 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.session.1h",
                systemImage: "stopwatch.fill",
                domain: .focus,
                category: .session,
                currentValue: longestSessionSeconds,
                targetValue: 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.session.2h",
                systemImage: "hourglass",
                domain: .focus,
                category: .session,
                currentValue: longestSessionSeconds,
                targetValue: 2 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.day.2h",
                systemImage: "sun.max.fill",
                domain: .focus,
                category: .daily,
                currentValue: bestDailyFocusSeconds,
                targetValue: 2 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.day.4h",
                systemImage: "shield.lefthalf.filled",
                domain: .focus,
                category: .daily,
                currentValue: bestDailyFocusSeconds,
                targetValue: 4 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.streak.5d",
                systemImage: "flame.fill",
                domain: .focus,
                category: .streak,
                currentValue: Double(longestStreakDays),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.streak.14d",
                systemImage: "calendar.badge.checkmark",
                domain: .focus,
                category: .streak,
                currentValue: Double(longestStreakDays),
                targetValue: 14,
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.streak.30d",
                systemImage: "calendar.circle.fill",
                domain: .focus,
                category: .streak,
                currentValue: Double(longestStreakDays),
                targetValue: 30,
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.week.5d",
                systemImage: "calendar.day.timeline.left",
                domain: .focus,
                category: .weekly,
                currentValue: Double(bestRollingWeekFocusDays),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "focus.comeback.7d",
                systemImage: "arrow.uturn.forward.circle.fill",
                domain: .focus,
                category: .comeback,
                currentValue: Double(comebackQuietDays),
                targetValue: 7,
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
            StatsAchievementProgress.catalogued(
                id: "sleep.first",
                systemImage: "bed.double.fill",
                domain: .sleep,
                category: .sleep,
                currentValue: Double(completedSessions.count),
                targetValue: 1,
            ),
            StatsAchievementProgress.catalogued(
                id: "sleep.total.56h",
                systemImage: "moon.zzz.fill",
                domain: .sleep,
                category: .sleep,
                currentValue: totalSeconds,
                targetValue: 56 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "sleep.session.7h",
                systemImage: "moon.stars.fill",
                domain: .sleep,
                category: .sleep,
                currentValue: longestSleepSeconds,
                targetValue: 7 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "sleep.streak.7d",
                systemImage: "calendar.badge.clock",
                domain: .sleep,
                category: .sleepStreak,
                currentValue: Double(longestSleepStreakDays),
                targetValue: 7,
            ),
        ]
    }

    private static func awayAchievements(
        sessions: [AwaySession],
        calendar: Calendar
    ) -> [StatsAchievementProgress] {
        let finishedSessions = sessions.filter { !$0.isActive }
        let completedTimedSessions = finishedSessions.filter { $0.state == .completed && !$0.isCountUp }
        let totalSeconds = finishedSessions.reduce(0) { total, session in
            total + session.durationSeconds()
        }
        let awayDays = uniqueDays(
            dates: finishedSessions.compactMap { $0.startedAt ?? $0.finishedAt },
            calendar: calendar
        )

        return [
            StatsAchievementProgress.catalogued(
                id: "away.first",
                systemImage: "lock.shield.fill",
                domain: .away,
                category: .away,
                currentValue: Double(finishedSessions.count),
                targetValue: 1,
            ),
            StatsAchievementProgress.catalogued(
                id: "away.total.5h",
                systemImage: "shield.checkered",
                domain: .away,
                category: .away,
                currentValue: totalSeconds,
                targetValue: 5 * 60 * 60,
                unit: .seconds
            ),
            StatsAchievementProgress.catalogued(
                id: "away.sessions.10",
                systemImage: "figure.walk.circle.fill",
                domain: .away,
                category: .away,
                currentValue: Double(finishedSessions.count),
                targetValue: 10,
            ),
            StatsAchievementProgress.catalogued(
                id: "away.completed.5",
                systemImage: "checkmark.shield.fill",
                domain: .away,
                category: .away,
                currentValue: Double(completedTimedSessions.count),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "away.days.5",
                systemImage: "calendar.day.timeline.left",
                domain: .away,
                category: .away,
                currentValue: Double(awayDays.count),
                targetValue: 5,
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
            StatsAchievementProgress.catalogued(
                id: "done.first",
                systemImage: "checkmark.seal.fill",
                domain: .done,
                category: .done,
                currentValue: Double(completedLogs.count),
                targetValue: 1,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.total.100",
                systemImage: "trophy.fill",
                domain: .done,
                category: .done,
                currentValue: Double(completedLogs.count),
                targetValue: 100,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.total.250",
                systemImage: "flag.checkered",
                domain: .done,
                category: .done,
                currentValue: Double(completedLogs.count),
                targetValue: 250,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.total.500",
                systemImage: "medal.fill",
                domain: .done,
                category: .done,
                currentValue: Double(completedLogs.count),
                targetValue: 500,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.total.1000",
                systemImage: "crown.fill",
                domain: .done,
                category: .done,
                currentValue: Double(completedLogs.count),
                targetValue: 1_000,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.day.5",
                systemImage: "5.circle.fill",
                domain: .done,
                category: .done,
                currentValue: Double(bestDailyDoneCount),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.day.10",
                systemImage: "10.circle.fill",
                domain: .done,
                category: .done,
                currentValue: Double(bestDailyDoneCount),
                targetValue: 10,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.day.20",
                systemImage: "20.circle.fill",
                domain: .done,
                category: .done,
                currentValue: Double(bestDailyDoneCount),
                targetValue: 20,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.streak.7d",
                systemImage: "flame.fill",
                domain: .done,
                category: .doneStreak,
                currentValue: Double(longestDoneStreakDays),
                targetValue: 7,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.streak.30d",
                systemImage: "calendar.badge.checkmark",
                domain: .done,
                category: .doneStreak,
                currentValue: Double(longestDoneStreakDays),
                targetValue: 30,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.streak.100d",
                systemImage: "calendar.circle.fill",
                domain: .done,
                category: .doneStreak,
                currentValue: Double(longestDoneStreakDays),
                targetValue: 100,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.week.5d",
                systemImage: "calendar.day.timeline.left",
                domain: .done,
                category: .doneStreak,
                currentValue: Double(bestRollingWeekDoneDays),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "done.week.7d",
                systemImage: "calendar",
                domain: .done,
                category: .doneStreak,
                currentValue: Double(bestRollingWeekDoneDays),
                targetValue: 7,
            ),
        ]
    }

}
