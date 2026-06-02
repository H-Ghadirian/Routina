import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct FocusAchievementStatsTests {
    @Test
    func achievementsUnlockTotalBlocksAndSessionDepth() throws {
        let calendar = makeTestCalendar()
        let sessions = [
            focusSession(
                startedAt: makeDate("2026-05-01T08:00:00Z"),
                durationSeconds: 2 * 60 * 60
            ),
            focusSession(
                startedAt: makeDate("2026-05-02T08:00:00Z"),
                durationSeconds: 8 * 60 * 60
            ),
        ]

        let achievements = FocusAchievementStats.achievements(
            sessions: sessions,
            calendar: calendar
        )

        let firstFocus = try #require(achievement("focus.first", in: achievements))
        let blockBuilder = try #require(achievement("focus.blocks.100", in: achievements))
        let tenHours = try #require(achievement("focus.total.10h", in: achievements))
        let oneHour = try #require(achievement("focus.session.1h", in: achievements))
        let twoHours = try #require(achievement("focus.session.2h", in: achievements))
        let fourHourDay = try #require(achievement("focus.day.4h", in: achievements))
        let fiftyHours = try #require(achievement("focus.total.50h", in: achievements))

        #expect(firstFocus.isEarned)
        #expect(blockBuilder.isEarned)
        #expect(tenHours.isEarned)
        #expect(oneHour.isEarned)
        #expect(twoHours.isEarned)
        #expect(fourHourDay.isEarned)
        #expect(!fiftyHours.isEarned)
        #expect(FocusAchievementStats.earnedCount(in: achievements) == 7)
    }

    @Test
    func achievementsCountFocusStreakAndRollingWeekDays() throws {
        let calendar = makeTestCalendar()
        let sessions = (0..<5).compactMap { dayOffset in
            calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: makeDate("2026-05-01T08:00:00Z")
            ).map {
                focusSession(startedAt: $0, durationSeconds: 20 * 60)
            }
        }

        let achievements = FocusAchievementStats.achievements(
            sessions: sessions,
            calendar: calendar
        )

        let fiveDayStreak = try #require(achievement("focus.streak.5d", in: achievements))
        let twoWeekStreak = try #require(achievement("focus.streak.14d", in: achievements))
        let steadyWeek = try #require(achievement("focus.week.5d", in: achievements))

        #expect(fiveDayStreak.isEarned)
        #expect(fiveDayStreak.progressText == "5 days / 5 days")
        #expect(!twoWeekStreak.isEarned)
        #expect(twoWeekStreak.progressText == "5 days / 14 days")
        #expect(steadyWeek.isEarned)
    }

    @Test
    func comebackFocusRequiresSevenQuietDaysBeforeReturn() throws {
        let calendar = makeTestCalendar()
        let sessions = [
            focusSession(
                startedAt: makeDate("2026-05-01T08:00:00Z"),
                durationSeconds: 25 * 60
            ),
            focusSession(
                startedAt: makeDate("2026-05-09T08:00:00Z"),
                durationSeconds: 25 * 60
            ),
        ]

        let achievements = FocusAchievementStats.achievements(
            sessions: sessions,
            calendar: calendar
        )

        let comeback = try #require(achievement("focus.comeback.7d", in: achievements))

        #expect(comeback.isEarned)
        #expect(comeback.progressText == "7 quiet days / 7 quiet days")
    }

    @Test
    func achievementsIncludeSleepAwayAndDoneBadges() throws {
        let calendar = makeTestCalendar()
        let sleepSessions = (0..<7).compactMap { dayOffset -> SleepSession? in
            guard let startedAt = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: makeDate("2026-05-01T22:00:00Z")
            ) else { return nil }

            return SleepSession(
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(8 * 60 * 60)
            )
        }
        let awaySessions = (0..<10).compactMap { index -> AwaySession? in
            guard let startedAt = calendar.date(
                byAdding: .hour,
                value: index,
                to: makeDate("2026-05-01T08:00:00Z")
            ) else { return nil }
            let finishedAt = startedAt.addingTimeInterval(30 * 60)
            let completedAt = index < 5 ? finishedAt : nil
            let endedEarlyAt = index < 5 ? nil : finishedAt

            return AwaySession(
                preset: .reset,
                startedAt: startedAt,
                plannedDurationSeconds: 30 * 60,
                completedAt: completedAt,
                endedEarlyAt: endedEarlyAt
            )
        }
        let doneLogs = (0..<7).flatMap { dayOffset -> [RoutineLog] in
            guard let timestamp = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: makeDate("2026-05-01T09:00:00Z")
            ) else { return [] }
            let count = dayOffset == 0 ? 5 : 1
            return (0..<count).map { _ in
                RoutineLog(timestamp: timestamp, taskID: UUID(), kind: .completed)
            }
        }

        let achievements = StatsAchievementStats.achievements(
            focusSessions: [],
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            logs: doneLogs,
            calendar: calendar
        )

        let sleepTotal = try #require(achievement("sleep.total.56h", in: achievements))
        let sleepStreak = try #require(achievement("sleep.streak.7d", in: achievements))
        let awayTotal = try #require(achievement("away.total.5h", in: achievements))
        let awayCompleted = try #require(achievement("away.completed.5", in: achievements))
        let doneDay = try #require(achievement("done.day.5", in: achievements))
        let tenDoneDay = try #require(achievement("done.day.10", in: achievements))
        let doneStreak = try #require(achievement("done.streak.7d", in: achievements))
        let thirtyDayStreak = try #require(achievement("done.streak.30d", in: achievements))
        let everydayWeek = try #require(achievement("done.week.7d", in: achievements))
        let doneCentury = try #require(achievement("done.total.100", in: achievements))
        let quarterKDone = try #require(achievement("done.total.250", in: achievements))

        #expect(sleepTotal.isEarned)
        #expect(sleepTotal.domain == .sleep)
        #expect(sleepTotal.progressText == "56h / 56h")
        #expect(sleepStreak.isEarned)
        #expect(awayTotal.isEarned)
        #expect(awayTotal.domain == .away)
        #expect(awayTotal.progressText == "5h / 5h")
        #expect(awayCompleted.isEarned)
        #expect(doneDay.isEarned)
        #expect(doneDay.domain == .done)
        #expect(!tenDoneDay.isEarned)
        #expect(tenDoneDay.progressText == "5 done / 10 done")
        #expect(doneStreak.isEarned)
        #expect(thirtyDayStreak.progressText == "7 days / 30 days")
        #expect(everydayWeek.isEarned)
        #expect(!doneCentury.isEarned)
        #expect(!quarterKDone.isEarned)
    }

    @Test
    func achievementsIncludeEmotionPlaceGoalAndNoteBadges() throws {
        let calendar = makeTestCalendar()
        let startDate = makeDate("2026-05-01T09:00:00Z")
        let emotionLogs = EmotionFamily.allCases.enumerated().compactMap { index, family -> EmotionLog? in
            guard let createdAt = calendar.date(byAdding: .day, value: index, to: startDate) else { return nil }
            return EmotionLog(
                family: family,
                label: family.defaultLabel,
                valence: 0.2,
                arousal: 0.1,
                intensity: 3,
                reflection: "Reflection \(index)",
                linkedTaskID: index < 4 ? UUID() : nil,
                createdAt: createdAt
            )
        }

        let notes = (0..<7).compactMap { index -> RoutineNote? in
            guard let createdAt = calendar.date(byAdding: .day, value: index, to: startDate) else { return nil }
            return RoutineNote(
                title: "Note \(index)",
                body: "Body \(index)",
                tags: index < 5 ? ["journal"] : [],
                imageData: index == 0 ? Data([1]) : nil,
                voiceNoteData: index == 1 ? Data([1]) : nil,
                voiceNoteDurationSeconds: index == 1 ? 12 : nil,
                voiceNoteCreatedAt: index == 1 ? createdAt : nil,
                createdAt: createdAt
            )
        }
        let noteAttachmentNoteIDs = Set(notes.prefix(3).map(\.id))

        let parentGoalID = UUID()
        let goals = (0..<5).compactMap { index -> RoutineGoal? in
            let id = index == 0 ? parentGoalID : UUID()
            guard let targetDate = calendar.date(byAdding: .day, value: index + 10, to: startDate) else { return nil }
            return RoutineGoal(
                id: id,
                title: "Goal \(index)",
                targetDate: targetDate,
                tags: ["growth"],
                status: index == 3 ? .archived : .active,
                parentGoalID: index == 0 || index == 4 ? nil : parentGoalID,
                createdAt: startDate
            )
        }

        let placeIDs = (0..<5).map { _ in UUID() }
        let places = placeIDs.enumerated().map { index, id in
            RoutinePlace(
                id: id,
                name: "Place \(index)",
                latitude: Double(index),
                longitude: Double(index)
            )
        }
        let placeCheckInSessions = (0..<7).compactMap { index -> PlaceCheckInSession? in
            guard let startedAt = calendar.date(byAdding: .day, value: index, to: startDate) else { return nil }
            let placeIndex = index % placeIDs.count
            return PlaceCheckInSession(
                placeID: placeIDs[placeIndex],
                placeName: "Place \(placeIndex)",
                activity: .work,
                note: index < 3 ? "Context \(index)" : nil,
                imageData: index == 3 ? Data([1]) : nil,
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(30 * 60)
            )
        }

        let achievements = StatsAchievementStats.achievements(
            focusSessions: [],
            logs: [],
            emotionLogs: emotionLogs,
            notes: notes,
            noteAttachmentNoteIDs: noteAttachmentNoteIDs,
            goals: goals,
            places: places,
            placeCheckInSessions: placeCheckInSessions,
            calendar: calendar
        )

        let emotionSpectrum = try #require(achievement("emotion.family.all", in: achievements))
        let emotionReflections = try #require(achievement("emotion.reflection.10", in: achievements))
        let placeLibrary = try #require(achievement("place.saved.5", in: achievements))
        let placeActivity = try #require(achievement("place.activity.10", in: achievements))
        let goalTree = try #require(achievement("goal.child.3", in: achievements))
        let archivedGoal = try #require(achievement("goal.archived.1", in: achievements))
        let noteStreak = try #require(achievement("note.streak.7d", in: achievements))
        let mediaNotes = try #require(achievement("note.media.10", in: achievements))

        #expect(emotionSpectrum.isEarned)
        #expect(emotionSpectrum.domain == .emotions)
        #expect(!emotionReflections.isEarned)
        #expect(emotionReflections.progressText == "8 reflections / 10 reflections")
        #expect(placeLibrary.isEarned)
        #expect(placeLibrary.domain == .places)
        #expect(!placeActivity.isEarned)
        #expect(placeActivity.progressText == "7 activities / 10 activities")
        #expect(goalTree.isEarned)
        #expect(goalTree.domain == .goals)
        #expect(archivedGoal.isEarned)
        #expect(noteStreak.isEarned)
        #expect(noteStreak.domain == .notes)
        #expect(!mediaNotes.isEarned)
        #expect(mediaNotes.progressText == "3 media notes / 10 media notes")
    }

    @Test
    func displayOrderShowsUnearnedAchievementsBeforeEarnedOnes() throws {
        let calendar = makeTestCalendar()
        let sessions = [
            focusSession(
                startedAt: makeDate("2026-05-01T08:00:00Z"),
                durationSeconds: 2 * 60 * 60
            ),
            focusSession(
                startedAt: makeDate("2026-05-02T08:00:00Z"),
                durationSeconds: 8 * 60 * 60
            ),
        ]
        let achievements = FocusAchievementStats.achievements(
            sessions: sessions,
            calendar: calendar
        )

        let orderedAchievements = FocusAchievementStats.displayOrdered(achievements)
        let firstEarnedIndex = try #require(orderedAchievements.firstIndex { $0.isEarned })
        let unearnedIDs = achievements.filter { !$0.isEarned }.map(\.id)
        let earnedIDs = achievements.filter(\.isEarned).map(\.id)

        #expect(orderedAchievements[..<firstEarnedIndex].allSatisfy { !$0.isEarned })
        #expect(orderedAchievements[firstEarnedIndex...].allSatisfy { $0.isEarned })
        #expect(orderedAchievements.filter { !$0.isEarned }.map(\.id) == unearnedIDs)
        #expect(orderedAchievements.filter(\.isEarned).map(\.id) == earnedIDs)
    }

    private func achievement(
        _ id: String,
        in achievements: [FocusAchievementProgress]
    ) -> FocusAchievementProgress? {
        achievements.first { $0.id == id }
    }

    private func focusSession(
        startedAt: Date,
        durationSeconds: TimeInterval
    ) -> FocusSession {
        FocusSession(
            taskID: UUID(),
            startedAt: startedAt,
            plannedDurationSeconds: durationSeconds,
            completedAt: startedAt.addingTimeInterval(durationSeconds)
        )
    }
}
