import Foundation

extension StatsAchievementStats {
    static func emotionAchievements(
        logs: [EmotionLog],
        calendar: Calendar,
        includingPlaces: Bool = true
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
            StatsAchievementProgress.catalogued(
                id: "emotion.first",
                systemImage: "heart.text.square.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(logs.count),
                targetValue: 1,
            ),
            StatsAchievementProgress.catalogued(
                id: "emotion.total.25",
                systemImage: "books.vertical.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(logs.count),
                targetValue: 25,
            ),
            StatsAchievementProgress.catalogued(
                id: "emotion.total.100",
                systemImage: "map.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(logs.count),
                targetValue: 100,
            ),
            StatsAchievementProgress.catalogued(
                id: "emotion.days.7",
                systemImage: "calendar.badge.plus",
                domain: .emotions,
                category: .emotionStreak,
                currentValue: Double(emotionDays.count),
                targetValue: 7,
            ),
            StatsAchievementProgress.catalogued(
                id: "emotion.streak.14d",
                systemImage: "calendar.badge.clock",
                domain: .emotions,
                category: .emotionStreak,
                currentValue: Double(longestEmotionStreakDays),
                targetValue: 14,
            ),
            StatsAchievementProgress.catalogued(
                id: "emotion.family.all",
                systemImage: "sparkles",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(familyCount),
                targetValue: Double(EmotionFamily.allCases.count),
            ),
            StatsAchievementProgress.catalogued(
                id: "emotion.reflection.10",
                systemImage: "text.bubble.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(reflectedLogCount),
                targetValue: 10,
            ),
            StatsAchievementProgress.catalogued(
                id: "emotion.linked.10",
                subtitleVariant: includingPlaces ? .standard : .withoutPlaces,
                systemImage: "link.circle.fill",
                domain: .emotions,
                category: .emotion,
                currentValue: Double(linkedLogCount),
                targetValue: 10,
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
            StatsAchievementProgress.catalogued(
                id: "place.saved.first",
                systemImage: "mappin.and.ellipse",
                domain: .places,
                category: .place,
                currentValue: Double(places.count),
                targetValue: 1,
            ),
            StatsAchievementProgress.catalogued(
                id: "place.saved.5",
                systemImage: "map.circle.fill",
                domain: .places,
                category: .place,
                currentValue: Double(places.count),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "place.checkin.first",
                systemImage: "location.fill",
                domain: .places,
                category: .place,
                currentValue: Double(finishedSessions.count),
                targetValue: 1,
            ),
            StatsAchievementProgress.catalogued(
                id: "place.checkin.25",
                systemImage: "figure.walk.circle.fill",
                domain: .places,
                category: .place,
                currentValue: Double(finishedSessions.count),
                targetValue: 25,
            ),
            StatsAchievementProgress.catalogued(
                id: "place.days.7",
                systemImage: "calendar.day.timeline.left",
                domain: .places,
                category: .placeStreak,
                currentValue: Double(checkInDays.count),
                targetValue: 7,
            ),
            StatsAchievementProgress.catalogued(
                id: "place.unique.5",
                systemImage: "mappin.circle.fill",
                domain: .places,
                category: .place,
                currentValue: Double(uniqueVisitedPlaceCount),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "place.activity.10",
                systemImage: "tag.fill",
                domain: .places,
                category: .place,
                currentValue: Double(activitySessionCount),
                targetValue: 10,
            ),
            StatsAchievementProgress.catalogued(
                id: "place.detail.5",
                systemImage: "photo.on.rectangle.angled",
                domain: .places,
                category: .place,
                currentValue: Double(detailedSessionCount),
                targetValue: 5,
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
            StatsAchievementProgress.catalogued(
                id: "goal.first",
                systemImage: "target",
                domain: .goals,
                category: .goal,
                currentValue: Double(goals.count),
                targetValue: 1,
            ),
            StatsAchievementProgress.catalogued(
                id: "goal.total.5",
                systemImage: "list.star",
                domain: .goals,
                category: .goal,
                currentValue: Double(goals.count),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "goal.total.20",
                systemImage: "folder.badge.gearshape",
                domain: .goals,
                category: .goal,
                currentValue: Double(goals.count),
                targetValue: 20,
            ),
            StatsAchievementProgress.catalogued(
                id: "goal.active.3",
                systemImage: "scope",
                domain: .goals,
                category: .goal,
                currentValue: Double(activeGoalCount),
                targetValue: 3,
            ),
            StatsAchievementProgress.catalogued(
                id: "goal.targetDate.5",
                systemImage: "calendar.badge.clock",
                domain: .goals,
                category: .goal,
                currentValue: Double(targetedGoalCount),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "goal.tagged.5",
                systemImage: "tag.circle.fill",
                domain: .goals,
                category: .goal,
                currentValue: Double(taggedGoalCount),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "goal.child.3",
                systemImage: "point.3.connected.trianglepath.dotted",
                domain: .goals,
                category: .goal,
                currentValue: Double(childGoalCount),
                targetValue: 3,
            ),
            StatsAchievementProgress.catalogued(
                id: "goal.archived.1",
                systemImage: "archivebox.fill",
                domain: .goals,
                category: .goal,
                currentValue: Double(archivedGoalCount),
                targetValue: 1,
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
            StatsAchievementProgress.catalogued(
                id: "note.first",
                systemImage: "note.text",
                domain: .notes,
                category: .note,
                currentValue: Double(notes.count),
                targetValue: 1,
            ),
            StatsAchievementProgress.catalogued(
                id: "note.total.25",
                systemImage: "doc.text.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(notes.count),
                targetValue: 25,
            ),
            StatsAchievementProgress.catalogued(
                id: "note.total.100",
                systemImage: "tray.full.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(notes.count),
                targetValue: 100,
            ),
            StatsAchievementProgress.catalogued(
                id: "note.tagged.10",
                systemImage: "tag.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(taggedNoteCount),
                targetValue: 10,
            ),
            StatsAchievementProgress.catalogued(
                id: "note.media.10",
                systemImage: "paperclip.circle.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(mediaNoteCount),
                targetValue: 10,
            ),
            StatsAchievementProgress.catalogued(
                id: "note.voice.5",
                systemImage: "waveform.circle.fill",
                domain: .notes,
                category: .note,
                currentValue: Double(voiceNoteCount),
                targetValue: 5,
            ),
            StatsAchievementProgress.catalogued(
                id: "note.streak.7d",
                systemImage: "calendar.badge.checkmark",
                domain: .notes,
                category: .noteStreak,
                currentValue: Double(longestNoteStreakDays),
                targetValue: 7,
            ),
            StatsAchievementProgress.catalogued(
                id: "note.week.5d",
                systemImage: "calendar.day.timeline.left",
                domain: .notes,
                category: .noteStreak,
                currentValue: Double(bestRollingWeekNoteDays),
                targetValue: 5,
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
