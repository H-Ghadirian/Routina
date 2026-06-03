import Foundation

enum StatsAchievementCelebrationPeriod: String, CaseIterable, Equatable, Identifiable {
    case today
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        case .year:
            return "This Year"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            return "sun.max.fill"
        case .week:
            return "calendar.day.timeline.left"
        case .month:
            return "calendar"
        case .year:
            return "sparkles"
        }
    }

    func contains(
        _ date: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let date,
              let interval = dateInterval(referenceDate: referenceDate, calendar: calendar)
        else { return false }

        return interval.contains(date)
    }

    private func dateInterval(
        referenceDate: Date,
        calendar: Calendar
    ) -> DateInterval? {
        switch self {
        case .today:
            return calendar.dateInterval(of: .day, for: referenceDate)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        case .month:
            return calendar.dateInterval(of: .month, for: referenceDate)
        case .year:
            return calendar.dateInterval(of: .year, for: referenceDate)
        }
    }
}

struct StatsAchievementCelebrationHighlight: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
    let domain: StatsAchievementDomain
}

struct StatsAchievementCelebration: Equatable, Identifiable {
    let period: StatsAchievementCelebrationPeriod
    let highlights: [StatsAchievementCelebrationHighlight]

    var id: String { period.id }
}

extension StatsAchievementStats {
    static func celebrationPeriods(
        focusSessions: [FocusSession],
        sleepSessions: [SleepSession] = [],
        awaySessions: [AwaySession] = [],
        logs: [RoutineLog] = [],
        emotionLogs: [EmotionLog] = [],
        notes: [RoutineNote] = [],
        goals: [RoutineGoal] = [],
        places: [RoutinePlace] = [],
        placeCheckInSessions: [PlaceCheckInSession] = [],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [StatsAchievementCelebration] {
        StatsAchievementCelebrationPeriod.allCases.compactMap { period in
            let highlights = celebrationHighlights(
                for: period,
                focusSessions: focusSessions,
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

            guard !highlights.isEmpty else { return nil }
            return StatsAchievementCelebration(period: period, highlights: highlights)
        }
    }

    private static func celebrationHighlights(
        for period: StatsAchievementCelebrationPeriod,
        focusSessions: [FocusSession],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        logs: [RoutineLog],
        emotionLogs: [EmotionLog],
        notes: [RoutineNote],
        goals: [RoutineGoal],
        places: [RoutinePlace],
        placeCheckInSessions: [PlaceCheckInSession],
        referenceDate: Date,
        calendar: Calendar
    ) -> [StatsAchievementCelebrationHighlight] {
        var highlights: [StatsAchievementCelebrationHighlight] = []

        let doneCount = logs.filter { log in
            log.kind == .completed
                && period.contains(log.timestamp, referenceDate: referenceDate, calendar: calendar)
        }.count
        appendCountHighlight(
            id: "done",
            title: "Done",
            count: doneCount,
            singular: "done",
            plural: "done",
            systemImage: "checkmark.seal.fill",
            domain: .done,
            to: &highlights
        )

        let completedFocusSessions = focusSessions.filter { session in
            session.state == .completed
                && period.contains(
                    session.completedAt ?? session.startedAt,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
        }
        appendDurationHighlight(
            id: "focus",
            title: "Focus",
            seconds: completedFocusSessions.reduce(0) { $0 + $1.actualDurationSeconds },
            fallbackCount: completedFocusSessions.count,
            singularFallback: "session",
            pluralFallback: "sessions",
            systemImage: "timer",
            domain: .focus,
            to: &highlights
        )

        let completedSleepSessions = sleepSessions.filter { session in
            !session.isActive
                && period.contains(
                    session.endedAt ?? session.startedAt,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
        }
        appendDurationHighlight(
            id: "sleep",
            title: "Sleep",
            seconds: completedSleepSessions.reduce(0) { $0 + $1.durationSeconds() },
            fallbackCount: completedSleepSessions.count,
            singularFallback: "session",
            pluralFallback: "sessions",
            systemImage: "bed.double.fill",
            domain: .sleep,
            to: &highlights
        )

        let finishedAwaySessions = awaySessions.filter { session in
            !session.isActive
                && period.contains(
                    session.finishedAt ?? session.startedAt,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
        }
        appendDurationHighlight(
            id: "away",
            title: "Away",
            seconds: finishedAwaySessions.reduce(0) { $0 + $1.durationSeconds() },
            fallbackCount: finishedAwaySessions.count,
            singularFallback: "session",
            pluralFallback: "sessions",
            systemImage: "lock.shield.fill",
            domain: .away,
            to: &highlights
        )

        let emotionCount = emotionLogs.filter { log in
            period.contains(log.createdAt, referenceDate: referenceDate, calendar: calendar)
        }.count
        appendCountHighlight(
            id: "emotions",
            title: "Emotions",
            count: emotionCount,
            singular: "log",
            plural: "logs",
            systemImage: "heart.text.square.fill",
            domain: .emotions,
            to: &highlights
        )

        let noteCount = notes.filter { note in
            period.contains(note.createdAt, referenceDate: referenceDate, calendar: calendar)
        }.count
        appendCountHighlight(
            id: "notes",
            title: "Notes",
            count: noteCount,
            singular: "note",
            plural: "notes",
            systemImage: "note.text",
            domain: .notes,
            to: &highlights
        )

        let goalCount = goals.filter { goal in
            period.contains(goal.createdAt, referenceDate: referenceDate, calendar: calendar)
        }.count
        appendCountHighlight(
            id: "goals",
            title: "Goals",
            count: goalCount,
            singular: "goal",
            plural: "goals",
            systemImage: "target",
            domain: .goals,
            to: &highlights
        )

        let savedPlaceCount = places.filter { place in
            period.contains(place.createdAt, referenceDate: referenceDate, calendar: calendar)
        }.count
        appendCountHighlight(
            id: "places.saved",
            title: "Places",
            count: savedPlaceCount,
            singular: "place",
            plural: "places",
            systemImage: "mappin.and.ellipse",
            domain: .places,
            to: &highlights
        )

        let finishedCheckInCount = placeCheckInSessions.filter { session in
            !session.isActive
                && period.contains(
                    session.endedAt ?? session.startedAt ?? session.createdAt,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
        }.count
        appendCountHighlight(
            id: "places.checkins",
            title: "Check-Ins",
            count: finishedCheckInCount,
            singular: "check-in",
            plural: "check-ins",
            systemImage: "location.fill",
            domain: .places,
            to: &highlights
        )

        return highlights
    }

    private static func appendCountHighlight(
        id: String,
        title: String,
        count: Int,
        singular: String,
        plural: String,
        systemImage: String,
        domain: StatsAchievementDomain,
        to highlights: inout [StatsAchievementCelebrationHighlight]
    ) {
        guard count > 0 else { return }

        highlights.append(
            StatsAchievementCelebrationHighlight(
                id: id,
                title: title,
                value: "\(count.formatted()) \(count == 1 ? singular : plural)",
                systemImage: systemImage,
                domain: domain
            )
        )
    }

    private static func appendDurationHighlight(
        id: String,
        title: String,
        seconds: TimeInterval,
        fallbackCount: Int,
        singularFallback: String,
        pluralFallback: String,
        systemImage: String,
        domain: StatsAchievementDomain,
        to highlights: inout [StatsAchievementCelebrationHighlight]
    ) {
        if seconds > 0 {
            highlights.append(
                StatsAchievementCelebrationHighlight(
                    id: id,
                    title: title,
                    value: StatsAchievementUnit.seconds.text(for: seconds),
                    systemImage: systemImage,
                    domain: domain
                )
            )
            return
        }

        appendCountHighlight(
            id: id,
            title: title,
            count: fallbackCount,
            singular: singularFallback,
            plural: pluralFallback,
            systemImage: systemImage,
            domain: domain,
            to: &highlights
        )
    }
}
