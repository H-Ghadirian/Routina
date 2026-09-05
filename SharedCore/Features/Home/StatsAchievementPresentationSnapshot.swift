import Foundation

struct StatsAchievementPresentationSnapshot: Equatable {
    var achievements: [StatsAchievementProgress] = []
    var earnedAchievementIDsByPeriod: [StatsAchievementCelebrationPeriod: Set<String>] = [:]
    var celebrations: [StatsAchievementCelebration] = []

    static func build(
        focusSessions: [FocusSession],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        logs: [RoutineLog],
        emotionLogs: [EmotionLog],
        notes: [RoutineNote],
        noteAttachmentNoteIDs: Set<UUID>,
        goals: [RoutineGoal],
        places: [RoutinePlace],
        placeCheckInSessions: [PlaceCheckInSession],
        referenceDate: Date,
        calendar: Calendar
    ) -> Self {
        let canonicalFocusSessions = FocusStatsSessionCanonicalization.canonicalTaskSessions(
            focusSessions
        )
        return Self(
            achievements: StatsAchievementStats.achievements(
                focusSessions: canonicalFocusSessions,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                logs: logs,
                emotionLogs: emotionLogs,
                notes: notes,
                noteAttachmentNoteIDs: noteAttachmentNoteIDs,
                goals: goals,
                places: places,
                placeCheckInSessions: placeCheckInSessions,
                calendar: calendar
            ),
            earnedAchievementIDsByPeriod: StatsAchievementStats.achievementIDsEarnedByPeriod(
                focusSessions: canonicalFocusSessions,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                logs: logs,
                emotionLogs: emotionLogs,
                notes: notes,
                noteAttachmentNoteIDs: noteAttachmentNoteIDs,
                goals: goals,
                places: places,
                placeCheckInSessions: placeCheckInSessions,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            celebrations: StatsAchievementStats.celebrationPeriods(
                focusSessions: canonicalFocusSessions,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                logs: logs,
                emotionLogs: emotionLogs,
                notes: notes,
                goals: goals,
                places: places,
                placeCheckInSessions: placeCheckInSessions,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }

    func filteringDomains(
        _ isIncluded: (StatsAchievementDomain) -> Bool
    ) -> Self {
        Self(
            achievements: achievements.filter { isIncluded($0.domain) },
            earnedAchievementIDsByPeriod: earnedAchievementIDsByPeriod,
            celebrations: celebrations.compactMap { celebration in
                let highlights = celebration.highlights.filter {
                    isIncluded($0.domain)
                }
                guard !highlights.isEmpty else { return nil }
                return StatsAchievementCelebration(
                    period: celebration.period,
                    highlights: highlights
                )
            }
        )
    }
}
