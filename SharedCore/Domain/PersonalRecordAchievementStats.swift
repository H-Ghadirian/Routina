import Foundation

extension StatsAchievementStats {
    static func emotionAchievements(
        logs: [EmotionLog],
        calendar: Calendar
    ) -> [StatsAchievementProgress] {
        let emotionDays = uniqueDays(
            dates: logs.compactMap(\.createdAt),
            calendar: calendar
        )
        let longestEmotionStreakDays = longestStreak(in: emotionDays, calendar: calendar)
        let reflectedLogCount = logs.filter { EmotionLog.cleanedText($0.reflection) != nil }.count
        let linkedLogCount = logs.filter(\.hasContextLinks).count
        let familyCount = Set(logs.flatMap { log in
            log.families.map(\.rawValue)
        }).count

        return [
            StatsAchievementProgress(
                id: "emotion.first",
                title: "First Emotion",
                subtitle: "Log your first emotion.",
                systemImage: "heart.text.square.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(logs.count),
                targetValue: 1,
                unit: .count(singular: "log", plural: "logs")
            ),
            StatsAchievementProgress(
                id: "emotion.total.25",
                title: "Feeling Library",
                subtitle: "Log 25 emotions.",
                systemImage: "books.vertical.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(logs.count),
                targetValue: 25,
                unit: .count(singular: "log", plural: "logs")
            ),
            StatsAchievementProgress(
                id: "emotion.total.100",
                title: "Emotion Atlas",
                subtitle: "Log 100 emotions.",
                systemImage: "map.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(logs.count),
                targetValue: 100,
                unit: .count(singular: "log", plural: "logs")
            ),
            StatsAchievementProgress(
                id: "emotion.days.7",
                title: "Seven Check-In Days",
                subtitle: "Log emotions on seven different days.",
                systemImage: "calendar.badge.plus",
                domain: .emotions,
                category: .emotionStreak,
                currentValue: Double(emotionDays.count),
                targetValue: 7,
                unit: .count(singular: "day", plural: "days")
            ),
            StatsAchievementProgress(
                id: "emotion.streak.14d",
                title: "Two-Week Feeling Thread",
                subtitle: "Log emotions on 14 days in a row.",
                systemImage: "calendar.badge.clock",
                domain: .emotions,
                category: .emotionStreak,
                currentValue: Double(longestEmotionStreakDays),
                targetValue: 14,
                unit: .count(singular: "day", plural: "days")
            ),
            StatsAchievementProgress(
                id: "emotion.family.all",
                title: "Full Feeling Spectrum",
                subtitle: "Use every emotion family at least once.",
                systemImage: "sparkles",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(familyCount),
                targetValue: Double(EmotionFamily.allCases.count),
                unit: .count(singular: "family", plural: "families")
            ),
            StatsAchievementProgress(
                id: "emotion.reflection.10",
                title: "Ten Reflections",
                subtitle: "Add reflections to ten emotion logs.",
                systemImage: "text.bubble.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(reflectedLogCount),
                targetValue: 10,
                unit: .count(singular: "reflection", plural: "reflections")
            ),
            StatsAchievementProgress(
                id: "emotion.linked.10",
                title: "Context Weaver",
                subtitle: "Link ten emotions to tasks, notes, goals, places, or sleep.",
                systemImage: "link.circle.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(linkedLogCount),
                targetValue: 10,
                unit: .count(singular: "link", plural: "links")
            ),
        ]
    }

    static func placeAchievements(
        places: [RoutinePlace],
        sessions: [PlaceCheckInSession],
        calendar: Calendar
    ) -> [StatsAchievementProgress] {
        let finishedSessions = sessions.filter { !$0.isActive }
        let checkInDays = uniqueDays(
            dates: finishedSessions.compactMap { $0.startedAt ?? $0.endedAt ?? $0.createdAt },
            calendar: calendar
        )
        let uniqueVisitedPlaceCount = Set(finishedSessions.compactMap(placeKey)).count
        let activitySessionCount = finishedSessions.filter { $0.activity != nil }.count
        let detailedSessionCount = finishedSessions.filter { session in
            PlaceCheckInSession.cleanedNote(session.note) != nil || session.hasImage
        }.count

        return [
            StatsAchievementProgress(
                id: "place.saved.first",
                title: "First Saved Place",
                subtitle: "Save your first place.",
                systemImage: "mappin.and.ellipse",
                domain: .places,
                category: .place,
                currentValue: Double(places.count),
                targetValue: 1,
                unit: .count(singular: "place", plural: "places")
            ),
            StatsAchievementProgress(
                id: "place.saved.5",
                title: "Place Library",
                subtitle: "Save five places.",
                systemImage: "map.circle.fill",
                domain: .places,
                category: .place,
                currentValue: Double(places.count),
                targetValue: 5,
                unit: .count(singular: "place", plural: "places")
            ),
            StatsAchievementProgress(
                id: "place.checkin.first",
                title: "First Check-In",
                subtitle: "Finish your first place check-in.",
                systemImage: "location.fill",
                domain: .places,
                category: .place,
                currentValue: Double(finishedSessions.count),
                targetValue: 1,
                unit: .count(singular: "check-in", plural: "check-ins")
            ),
            StatsAchievementProgress(
                id: "place.checkin.25",
                title: "Neighborhood Regular",
                subtitle: "Finish 25 place check-ins.",
                systemImage: "figure.walk.circle.fill",
                domain: .places,
                category: .place,
                currentValue: Double(finishedSessions.count),
                targetValue: 25,
                unit: .count(singular: "check-in", plural: "check-ins")
            ),
            StatsAchievementProgress(
                id: "place.days.7",
                title: "Place Week",
                subtitle: "Check in on seven different days.",
                systemImage: "calendar.day.timeline.left",
                domain: .places,
                category: .placeStreak,
                currentValue: Double(checkInDays.count),
                targetValue: 7,
                unit: .count(singular: "day", plural: "days")
            ),
            StatsAchievementProgress(
                id: "place.unique.5",
                title: "Five-Place Loop",
                subtitle: "Visit five distinct places.",
                systemImage: "mappin.circle.fill",
                domain: .places,
                category: .place,
                currentValue: Double(uniqueVisitedPlaceCount),
                targetValue: 5,
                unit: .count(singular: "place", plural: "places")
            ),
            StatsAchievementProgress(
                id: "place.activity.10",
                title: "Activity Mapper",
                subtitle: "Add activities to ten check-ins.",
                systemImage: "tag.fill",
                domain: .places,
                category: .place,
                currentValue: Double(activitySessionCount),
                targetValue: 10,
                unit: .count(singular: "activity", plural: "activities")
            ),
            StatsAchievementProgress(
                id: "place.detail.5",
                title: "Place Notes",
                subtitle: "Add notes or images to five check-ins.",
                systemImage: "photo.on.rectangle.angled",
                domain: .places,
                category: .place,
                currentValue: Double(detailedSessionCount),
                targetValue: 5,
                unit: .count(singular: "detail", plural: "details")
            ),
        ]
    }

    static func goalAchievements(goals: [RoutineGoal]) -> [StatsAchievementProgress] {
        let activeGoalCount = goals.filter { $0.status == .active }.count
        let archivedGoalCount = goals.filter { $0.status == .archived }.count
        let targetedGoalCount = goals.filter { $0.targetDate != nil }.count
        let taggedGoalCount = goals.filter { !$0.tags.isEmpty }.count
        let childGoalCount = goals.filter { $0.parentGoalID != nil }.count

        return [
            StatsAchievementProgress(
                id: "goal.first",
                title: "First Goal",
                subtitle: "Create your first goal.",
                systemImage: "target",
                domain: .goals,
                category: .goal,
                currentValue: Double(goals.count),
                targetValue: 1,
                unit: .count(singular: "goal", plural: "goals")
            ),
            StatsAchievementProgress(
                id: "goal.total.5",
                title: "Goal Bench",
                subtitle: "Create five goals.",
                systemImage: "list.star",
                domain: .goals,
                category: .goal,
                currentValue: Double(goals.count),
                targetValue: 5,
                unit: .count(singular: "goal", plural: "goals")
            ),
            StatsAchievementProgress(
                id: "goal.total.20",
                title: "Goal Portfolio",
                subtitle: "Create 20 goals.",
                systemImage: "folder.badge.gearshape",
                domain: .goals,
                category: .goal,
                currentValue: Double(goals.count),
                targetValue: 20,
                unit: .count(singular: "goal", plural: "goals")
            ),
            StatsAchievementProgress(
                id: "goal.active.3",
                title: "Three Active Goals",
                subtitle: "Keep three goals active.",
                systemImage: "scope",
                domain: .goals,
                category: .goal,
                currentValue: Double(activeGoalCount),
                targetValue: 3,
                unit: .count(singular: "active goal", plural: "active goals")
            ),
            StatsAchievementProgress(
                id: "goal.targetDate.5",
                title: "Dated Intentions",
                subtitle: "Give five goals target dates.",
                systemImage: "calendar.badge.clock",
                domain: .goals,
                category: .goal,
                currentValue: Double(targetedGoalCount),
                targetValue: 5,
                unit: .count(singular: "dated goal", plural: "dated goals")
            ),
            StatsAchievementProgress(
                id: "goal.tagged.5",
                title: "Tagged Goals",
                subtitle: "Add tags to five goals.",
                systemImage: "tag.circle.fill",
                domain: .goals,
                category: .goal,
                currentValue: Double(taggedGoalCount),
                targetValue: 5,
                unit: .count(singular: "tagged goal", plural: "tagged goals")
            ),
            StatsAchievementProgress(
                id: "goal.child.3",
                title: "Goal Tree",
                subtitle: "Create three sub-goals.",
                systemImage: "point.3.connected.trianglepath.dotted",
                domain: .goals,
                category: .goal,
                currentValue: Double(childGoalCount),
                targetValue: 3,
                unit: .count(singular: "sub-goal", plural: "sub-goals")
            ),
            StatsAchievementProgress(
                id: "goal.archived.1",
                title: "Closed Loop",
                subtitle: "Archive your first completed or retired goal.",
                systemImage: "archivebox.fill",
                domain: .goals,
                category: .goal,
                currentValue: Double(archivedGoalCount),
                targetValue: 1,
                unit: .count(singular: "archived goal", plural: "archived goals")
            ),
        ]
    }

    static func noteAchievements(
        notes: [RoutineNote],
        noteAttachmentNoteIDs: Set<UUID>,
        calendar: Calendar
    ) -> [StatsAchievementProgress] {
        let noteDays = uniqueDays(
            dates: notes.compactMap(\.createdAt),
            calendar: calendar
        )
        let longestNoteStreakDays = longestStreak(in: noteDays, calendar: calendar)
        let bestRollingWeekNoteDays = bestActiveDaysInRollingWeek(noteDays, calendar: calendar)
        let taggedNoteCount = notes.filter { !$0.tags.isEmpty }.count
        let mediaNoteCount = notes.filter { note in
            note.hasImage || note.hasVoiceNote || noteAttachmentNoteIDs.contains(note.id)
        }.count
        let voiceNoteCount = notes.filter(\.hasVoiceNote).count

        return [
            StatsAchievementProgress(
                id: "note.first",
                title: "First Note",
                subtitle: "Create your first note.",
                systemImage: "note.text",
                domain: .notes,
                category: .note,
                currentValue: Double(notes.count),
                targetValue: 1,
                unit: .count(singular: "note", plural: "notes")
            ),
            StatsAchievementProgress(
                id: "note.total.25",
                title: "Notebook Stack",
                subtitle: "Create 25 notes.",
                systemImage: "doc.text.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(notes.count),
                targetValue: 25,
                unit: .count(singular: "note", plural: "notes")
            ),
            StatsAchievementProgress(
                id: "note.total.100",
                title: "Hundred Notes",
                subtitle: "Create 100 notes.",
                systemImage: "tray.full.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(notes.count),
                targetValue: 100,
                unit: .count(singular: "note", plural: "notes")
            ),
            StatsAchievementProgress(
                id: "note.tagged.10",
                title: "Tagged Notebook",
                subtitle: "Add tags to ten notes.",
                systemImage: "tag.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(taggedNoteCount),
                targetValue: 10,
                unit: .count(singular: "tagged note", plural: "tagged notes")
            ),
            StatsAchievementProgress(
                id: "note.media.10",
                title: "Media Notes",
                subtitle: "Add image, file, or voice media to ten notes.",
                systemImage: "paperclip.circle.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(mediaNoteCount),
                targetValue: 10,
                unit: .count(singular: "media note", plural: "media notes")
            ),
            StatsAchievementProgress(
                id: "note.voice.5",
                title: "Voice Notebook",
                subtitle: "Record voice on five notes.",
                systemImage: "waveform.circle.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(voiceNoteCount),
                targetValue: 5,
                unit: .count(singular: "voice note", plural: "voice notes")
            ),
            StatsAchievementProgress(
                id: "note.streak.7d",
                title: "Seven-Day Notes",
                subtitle: "Create notes on seven days in a row.",
                systemImage: "calendar.badge.checkmark",
                domain: .notes,
                category: .noteStreak,
                currentValue: Double(longestNoteStreakDays),
                targetValue: 7,
                unit: .count(singular: "day", plural: "days")
            ),
            StatsAchievementProgress(
                id: "note.week.5d",
                title: "Steady Note Week",
                subtitle: "Create notes on five days inside any seven-day span.",
                systemImage: "calendar.day.timeline.left",
                domain: .notes,
                category: .noteStreak,
                currentValue: Double(bestRollingWeekNoteDays),
                targetValue: 5,
                unit: .count(singular: "day", plural: "days")
            ),
        ]
    }

    static func focusSecondsByDay(
        sessions: [FocusSession],
        calendar: Calendar
    ) -> [Date: TimeInterval] {
        sessions.reduce(into: [Date: TimeInterval]()) { partialResult, session in
            guard let daySource = session.completedAt ?? session.startedAt else { return }
            partialResult[calendar.startOfDay(for: daySource), default: 0] += session.actualDurationSeconds
        }
    }

    static func placeKey(for session: PlaceCheckInSession) -> String? {
        if let placeID = session.placeID {
            return placeID.uuidString
        }

        guard let normalizedName = RoutinePlace.normalizedName(session.placeName)?.lowercased(),
              normalizedName != "unknown place"
        else {
            return nil
        }
        return normalizedName
    }

    static func uniqueDays(
        dates: [Date],
        calendar: Calendar
    ) -> [Date] {
        Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted()
    }

    static func longestStreak(
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

    static func bestActiveDaysInRollingWeek(
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

    static func longestQuietGapBeforeComeback(
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
