import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct StatsFeatureDerivedStateSupportTests {
    @Test
    func dailyBarXAxisDatesPreferActiveBarDates() {
        let calendar = makeTestCalendar()
        let startDate = makeDate("2026-01-01T00:00:00Z")
        let points = (0..<60).compactMap { offset -> DoneChartPoint? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                return nil
            }

            return DoneChartPoint(date: date, count: offset.isMultiple(of: 2) ? 1 : 0)
        }
        let activeDates = Set(points.filter { $0.count > 0 }.map(\.date))

        let axisDates = StatsChartPresentation(
            selectedRange: .year,
            isCompact: false
        ).dailyBarXAxisDates(from: points)

        #expect(axisDates.count == 24)
        #expect(axisDates.allSatisfy { activeDates.contains($0) })
        #expect(axisDates.first == points.first?.date)
        #expect(axisDates.last == points[58].date)
    }

    @Test
    func build_countsDoneCanceledAndMissedTimelineActivity() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Class",
            tags: ["Study"],
            createdAt: makeDate("2026-05-01T08:00:00Z")
        )
        let referenceDate = makeDate("2026-05-09T10:00:00Z")
        let logs = [
            RoutineLog(timestamp: makeDate("2026-05-07T18:30:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-05-08T18:30:00Z"), taskID: task.id, kind: .missed),
            RoutineLog(timestamp: makeDate("2026-05-09T18:30:00Z"), taskID: task.id, kind: .canceled)
        ]

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [task],
            logs: logs,
            focusSessions: [],
            selectedRange: .week,
            taskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: [],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(state.metrics.totalDoneCount == 1)
        #expect(state.metrics.totalCanceledCount == 1)
        #expect(state.metrics.totalMissedCount == 1)
        #expect(state.metrics.totalCount == 3)
        #expect(state.metrics.activeDayCount == 3)
    }

    @Test
    func build_countsEmotionNoteEventAndGoalStats() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-05-09T10:00:00Z")
        let recentEmotion = EmotionLog(
            family: .joy,
            label: "happy",
            valence: 1,
            arousal: 0.5,
            intensity: 5,
            createdAt: makeDate("2026-05-08T08:00:00Z")
        )
        let secondRecentEmotion = EmotionLog(
            family: .calm,
            label: "calm",
            valence: 1,
            arousal: -0.5,
            intensity: 3,
            createdAt: makeDate("2026-05-07T08:00:00Z")
        )
        let oldEmotion = EmotionLog(
            family: .sadness,
            label: "sad",
            valence: -1,
            arousal: -0.5,
            intensity: 2,
            createdAt: makeDate("2026-04-01T08:00:00Z")
        )
        let noteWithMedia = RoutineNote(
            title: "Photo note",
            imageData: Data([1]),
            createdAt: makeDate("2026-05-08T09:00:00Z")
        )
        let textNote = RoutineNote(
            body: "Plain note",
            createdAt: makeDate("2026-05-05T09:00:00Z")
        )
        let fileNote = RoutineNote(
            body: "File note",
            createdAt: makeDate("2026-05-06T09:00:00Z")
        )
        let oldNote = RoutineNote(
            body: "Old note",
            createdAt: makeDate("2026-04-01T09:00:00Z")
        )
        let recentEvent = RoutineEvent(
            title: "Sick day",
            isAllDay: true,
            startedAt: makeDate("2026-05-08T00:00:00Z"),
            endedAt: makeDate("2026-05-09T00:00:00Z")
        )
        let secondRecentEvent = RoutineEvent(
            title: "Appointment",
            isAllDay: false,
            startedAt: makeDate("2026-05-06T15:00:00Z"),
            endedAt: makeDate("2026-05-06T16:00:00Z")
        )
        let oldEvent = RoutineEvent(
            title: "Old travel",
            isAllDay: true,
            startedAt: makeDate("2026-04-01T00:00:00Z"),
            endedAt: makeDate("2026-04-02T00:00:00Z")
        )
        let activeGoal = RoutineGoal(
            title: "Launch",
            status: .active,
            createdAt: makeDate("2026-05-08T10:00:00Z")
        )
        let archivedGoal = RoutineGoal(
            title: "Done",
            status: .archived,
            createdAt: makeDate("2026-04-01T10:00:00Z")
        )

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [],
            logs: [],
            focusSessions: [],
            emotionLogs: [recentEmotion, secondRecentEmotion, oldEmotion],
            notes: [noteWithMedia, textNote, fileNote, oldNote],
            events: [recentEvent, secondRecentEvent, oldEvent],
            noteAttachmentNoteIDs: [fileNote.id],
            goals: [activeGoal, archivedGoal],
            selectedRange: .week,
            taskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: [],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(state.metrics.emotionLogCount == 2)
        #expect(state.metrics.emotionActiveDayCount == 2)
        #expect(state.metrics.averageEmotionIntensity == 4)
        #expect(state.metrics.noteCount == 3)
        #expect(state.metrics.noteWithMediaCount == 2)
        #expect(state.metrics.eventCount == 2)
        #expect(state.metrics.eventActiveDayCount == 2)
        #expect(state.metrics.activeGoalCount == 1)
        #expect(state.metrics.archivedGoalCount == 1)
        #expect(state.metrics.goalsCreatedCount == 1)
    }

    @Test
    func build_derivesFocusWeekdayAveragesFromDailyFocusSeries() {
        var calendar = makeTestCalendar()
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let task = RoutineTask(
            name: "Deep work",
            tags: ["Focus"],
            createdAt: makeDate("2026-03-01T08:00:00Z")
        )
        let referenceDate = makeDate("2026-03-08T12:00:00Z")
        let focusSessions = [
            FocusSession(
                taskID: task.id,
                startedAt: makeDate("2026-03-02T09:00:00Z"),
                completedAt: makeDate("2026-03-02T10:00:00Z")
            ),
            FocusSession(
                taskID: task.id,
                startedAt: makeDate("2026-03-04T14:00:00Z"),
                completedAt: makeDate("2026-03-04T14:30:00Z")
            )
        ]

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [task],
            logs: [],
            focusSessions: focusSessions,
            selectedRange: .week,
            taskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: [],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )

        let weekdayPoints = state.metrics.focusWeekdayAveragePoints
        #expect(weekdayPoints.map(\.shortSymbol) == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        #expect(weekdayPoints.map(\.contributingDayCount) == Array(repeating: 1, count: 7))
        #expect(weekdayPoints[0].seconds == TimeInterval(60 * 60))
        #expect(weekdayPoints[2].seconds == TimeInterval(30 * 60))
        #expect(state.metrics.highlightedFocusWeekdayAverage?.weekday == 2)
        #expect(state.metrics.focusWeekdayAverageUpperBound == 65)
    }

    @Test
    func summaryItemsIncludeHealthCardsWhenHealthSummaryIsPresent() {
        let items = StatsSummaryCardItemBuilder.items(
            metrics: StatsFeatureMetrics(),
            selectedRange: .week,
            chartPresentation: StatsChartPresentation(selectedRange: .week, isCompact: false),
            taskTypeFilter: .all,
            filteredTaskCount: 0,
            healthSummary: HealthStatsSummary(
                steps: 12_345,
                activeEnergyKilocalories: 456,
                walkingRunningDistanceMeters: 3_210,
                exerciseMinutes: 42,
                fetchedAt: makeDate("2026-05-09T10:00:00Z")
            )
        )

        let healthIdentifiers = items
            .map(\.accessibilityIdentifier)
            .filter { $0.hasPrefix("stats.summary.health.") }

        #expect(healthIdentifiers == [
            "stats.summary.health.steps",
            "stats.summary.health.activeCalories",
            "stats.summary.health.distance",
            "stats.summary.health.exercise"
        ])
    }
}
