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
    func build_groupsYearSparklineIntoTrailingTwelveMonths() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Practice",
            createdAt: makeDate("2026-03-05T08:00:00Z")
        )
        let logs = [
            RoutineLog(timestamp: makeDate("2026-03-05T18:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-03-20T18:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-04-10T18:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-06-08T18:00:00Z"), taskID: task.id, kind: .completed)
        ]

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [task],
            logs: logs,
            focusSessions: [],
            selectedRange: .year,
            taskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: [],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: makeDate("2026-06-09T10:00:00Z"),
            calendar: calendar
        )

        #expect(state.metrics.sparklinePoints.count == 12)
        #expect(state.metrics.sparklinePoints.first == DoneChartPoint(
            date: makeDate("2025-07-01T00:00:00Z"),
            count: 0
        ))
        #expect(state.metrics.sparklinePoints.last == DoneChartPoint(
            date: makeDate("2026-06-01T00:00:00Z"),
            count: 1
        ))
        #expect(state.metrics.sparklinePoints.first {
            calendar.isDate($0.date, equalTo: makeDate("2026-03-01T00:00:00Z"), toGranularity: .month)
        }?.count == 2)
        #expect(state.metrics.sparklinePoints.first {
            calendar.isDate($0.date, equalTo: makeDate("2026-04-01T00:00:00Z"), toGranularity: .month)
        }?.count == 1)
        #expect(state.metrics.sparklinePoints.first {
            calendar.isDate($0.date, equalTo: makeDate("2026-05-01T00:00:00Z"), toGranularity: .month)
        }?.count == 0)
        #expect(state.metrics.sparklineMaxCount == 2)
    }

    @Test
    func build_groupsMonthSparklineIntoWeekSizedBuckets() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Practice",
            createdAt: makeDate("2026-03-01T08:00:00Z")
        )
        let logs = [
            RoutineLog(timestamp: makeDate("2026-03-01T18:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-03-07T18:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-03-14T18:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-03-30T18:00:00Z"), taskID: task.id, kind: .completed)
        ]

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [task],
            logs: logs,
            focusSessions: [],
            selectedRange: .month,
            taskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: [],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: makeDate("2026-03-30T10:00:00Z"),
            calendar: calendar
        )

        #expect(state.metrics.sparklinePoints == [
            DoneChartPoint(date: makeDate("2026-03-01T00:00:00Z"), count: 2),
            DoneChartPoint(date: makeDate("2026-03-08T00:00:00Z"), count: 1),
            DoneChartPoint(date: makeDate("2026-03-15T00:00:00Z"), count: 0),
            DoneChartPoint(date: makeDate("2026-03-22T00:00:00Z"), count: 0),
            DoneChartPoint(date: makeDate("2026-03-29T00:00:00Z"), count: 1)
        ])
        #expect(state.metrics.sparklineMaxCount == 2)
    }

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
        #expect(state.metrics.outcomeMixChartPoints.count == 7)
        #expect(state.metrics.outcomeMixChartPoints.first { calendar.isDate($0.date, inSameDayAs: makeDate("2026-05-07T00:00:00Z")) }?.doneCount == 1)
        #expect(state.metrics.outcomeMixChartPoints.first { calendar.isDate($0.date, inSameDayAs: makeDate("2026-05-08T00:00:00Z")) }?.missedCount == 1)
        #expect(state.metrics.outcomeMixChartPoints.first { calendar.isDate($0.date, inSameDayAs: makeDate("2026-05-09T00:00:00Z")) }?.canceledCount == 1)
    }

    @Test
    func build_countsAssumedDoneDaysAndEstimatedTimeForFilteredDailyTracking() {
        let calendar = makeTestCalendar()
        let estimatedRoutine = RoutineTask(
            name: "Hydrate",
            tags: ["Health"],
            scheduleMode: .record,
            recurrenceRule: .interval(days: 1),
            createdAt: makeDate("2026-05-07T08:00:00Z"),
            autoAssumeDailyDone: true,
            estimatedDurationMinutes: 10
        )
        let noEstimateRoutine = RoutineTask(
            name: "Stretch",
            tags: ["Health"],
            scheduleMode: .record,
            recurrenceRule: .interval(days: 1),
            createdAt: makeDate("2026-05-09T08:00:00Z"),
            autoAssumeDailyDone: true
        )
        let hiddenRoutine = RoutineTask(
            name: "Read",
            tags: ["Hidden"],
            scheduleMode: .record,
            recurrenceRule: .interval(days: 1),
            createdAt: makeDate("2026-05-07T08:00:00Z"),
            autoAssumeDailyDone: true,
            estimatedDurationMinutes: 60
        )
        let referenceDate = makeDate("2026-05-09T10:00:00Z")
        let logs = [
            RoutineLog(
                timestamp: makeDate("2026-05-08T10:00:00Z"),
                taskID: estimatedRoutine.id,
                kind: .completed
            )
        ]

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [estimatedRoutine, noEstimateRoutine, hiddenRoutine],
            logs: logs,
            focusSessions: [],
            selectedRange: .week,
            taskTypeFilter: .records,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: ["Health"],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(state.metrics.assumedDoneCount == 3)
        #expect(state.metrics.totalAssumedEstimatedMinutes == 20)
        #expect(state.metrics.totalDoneCount == 1)
    }

    @Test
    func build_countsSleepSessionStats() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-05-09T10:00:00Z")
        let completedSleep = SleepSession(
            startedAt: makeDate("2026-05-07T22:00:00Z"),
            endedAt: makeDate("2026-05-08T06:00:00Z")
        )
        let activeSleep = SleepSession(
            startedAt: makeDate("2026-05-09T08:00:00Z"),
            endedAt: nil
        )
        let oldSleep = SleepSession(
            startedAt: makeDate("2026-04-25T22:00:00Z"),
            endedAt: makeDate("2026-04-26T06:00:00Z")
        )

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [],
            logs: [],
            focusSessions: [],
            sleepSessions: [completedSleep, activeSleep, oldSleep],
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

        #expect(state.metrics.sleepSessionCount == 2)
        #expect(state.metrics.completedSleepSessionCount == 1)
        #expect(state.metrics.totalSleepSeconds == TimeInterval(10 * 60 * 60))
        #expect(state.metrics.sleepActiveDayCount == 2)
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
        #expect(state.metrics.emotionTrendChartPoints.count == 2)
        #expect(state.metrics.emotionTrendChartPoints.first?.averageValence == 1)
        #expect(state.metrics.emotionTrendChartPoints.first?.averageArousal == -0.5)
        #expect(state.metrics.emotionTrendChartPoints.last?.averageIntensity == 5)
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
    func build_pairsFocusTimeWithCompletedWorkByDay() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Deep work",
            tags: ["Focus"],
            createdAt: makeDate("2026-03-01T08:00:00Z")
        )
        let referenceDate = makeDate("2026-03-08T12:00:00Z")
        let logs = [
            RoutineLog(timestamp: makeDate("2026-03-03T10:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-03-03T12:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-03-04T10:00:00Z"), taskID: task.id, kind: .missed)
        ]
        let focusSessions = [
            FocusSession(
                taskID: task.id,
                startedAt: makeDate("2026-03-03T09:00:00Z"),
                completedAt: makeDate("2026-03-03T09:45:00Z")
            ),
            FocusSession(
                taskID: task.id,
                startedAt: makeDate("2026-03-05T14:00:00Z"),
                completedAt: makeDate("2026-03-05T14:30:00Z")
            )
        ]

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [task],
            logs: logs,
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

        let pointsByDay = Dictionary(
            uniqueKeysWithValues: state.metrics.focusWorkChartPoints.map { ($0.date, $0) }
        )
        let completedFocusDay = pointsByDay[makeDate("2026-03-03T00:00:00Z")]
        let focusOnlyDay = pointsByDay[makeDate("2026-03-05T00:00:00Z")]

        #expect(completedFocusDay?.doneCount == 2)
        #expect(completedFocusDay?.focusSeconds == TimeInterval(45 * 60))
        #expect(completedFocusDay?.hasFocusAndDone == true)
        #expect(focusOnlyDay?.doneCount == 0)
        #expect(focusOnlyDay?.focusSeconds == TimeInterval(30 * 60))
    }

    @Test
    func build_comparesEstimatedAndActualCompletedWorkByDay() {
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            name: "Deep work",
            tags: ["Focus"],
            estimatedDurationMinutes: 40
        )
        let hiddenTask = RoutineTask(
            name: "Hidden",
            tags: ["Hidden"],
            estimatedDurationMinutes: 20
        )
        let referenceDate = makeDate("2026-03-08T12:00:00Z")
        let logs = [
            RoutineLog(
                timestamp: makeDate("2026-03-03T10:00:00Z"),
                taskID: task.id,
                kind: .completed,
                actualDurationMinutes: 55
            ),
            RoutineLog(
                timestamp: makeDate("2026-03-03T12:00:00Z"),
                taskID: hiddenTask.id,
                kind: .completed,
                actualDurationMinutes: 30
            )
        ]

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [task, hiddenTask],
            logs: logs,
            focusSessions: [],
            selectedRange: .week,
            taskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: ["Focus"],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )

        let point = state.metrics.estimateActualChartPoints.first {
            calendar.isDate($0.date, inSameDayAs: makeDate("2026-03-03T00:00:00Z"))
        }
        #expect(point?.estimatedMinutes == 40)
        #expect(point?.actualMinutes == 55)
        #expect(point?.trackedCompletionCount == 1)
    }

    @Test
    func build_summarizesTrackingCountsAndTimeForFilteredTasks() {
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-03-08T12:00:00Z")
        let entryTimeTracking = RoutineTask(
            name: "Research notes",
            tags: ["Focus"],
            scheduleMode: .record,
            createdAt: makeDate("2026-03-03T09:00:00Z"),
            actualDurationMinutes: 25
        )
        let loggedTracking = RoutineTask(
            name: "Review session",
            tags: ["Focus"],
            scheduleMode: .record,
            createdAt: makeDate("2026-03-03T09:00:00Z"),
            actualDurationMinutes: 90
        )
        let archivedTracking = RoutineTask(
            name: "Old audit",
            tags: ["Focus"],
            scheduleMode: .record,
            pausedAt: makeDate("2026-03-01T08:00:00Z"),
            createdAt: makeDate("2026-03-03T09:00:00Z"),
            actualDurationMinutes: 15
        )
        let hiddenTracking = RoutineTask(
            name: "Hidden analysis",
            tags: ["Hidden"],
            scheduleMode: .record,
            createdAt: makeDate("2026-03-03T09:00:00Z"),
            actualDurationMinutes: 100
        )
        let routine = RoutineTask(name: "Stretch", tags: ["Focus"])
        let logs = [
            RoutineLog(
                timestamp: makeDate("2026-03-04T10:00:00Z"),
                taskID: loggedTracking.id,
                kind: .completed,
                actualDurationMinutes: 40
            ),
            RoutineLog(
                timestamp: makeDate("2026-03-05T10:00:00Z"),
                taskID: loggedTracking.id,
                kind: .missed,
                actualDurationMinutes: 30
            ),
            RoutineLog(
                timestamp: makeDate("2026-02-20T10:00:00Z"),
                taskID: loggedTracking.id,
                kind: .completed,
                actualDurationMinutes: 60
            ),
            RoutineLog(
                timestamp: makeDate("2026-03-04T10:00:00Z"),
                taskID: hiddenTracking.id,
                kind: .completed,
                actualDurationMinutes: 100
            )
        ]

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [entryTimeTracking, loggedTracking, archivedTracking, hiddenTracking, routine],
            logs: logs,
            focusSessions: [],
            selectedRange: .week,
            taskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: ["Focus"],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(state.metrics.trackingEntryCount == 3)
        #expect(state.metrics.activeTrackingEntryCount == 2)
        #expect(state.metrics.archivedTrackingEntryCount == 1)
        #expect(state.metrics.completedTrackingLogCount == 1)
        #expect(state.metrics.totalTrackingActualMinutes == 80)
    }

    @Test
    func build_summarizesGoalMomentumForFilteredTasks() {
        let calendar = makeTestCalendar()
        let goal = RoutineGoal(title: "Launch", emoji: "🚀", status: .active)
        let hiddenGoal = RoutineGoal(title: "Hidden", status: .active)
        let task = RoutineTask(
            name: "Release notes",
            tags: ["Launch"],
            goalIDs: [goal.id],
            createdAt: makeDate("2026-03-01T08:00:00Z")
        )
        let hiddenTask = RoutineTask(
            name: "Draft",
            tags: ["Hidden"],
            goalIDs: [hiddenGoal.id],
            createdAt: makeDate("2026-03-01T08:00:00Z")
        )
        let referenceDate = makeDate("2026-03-08T12:00:00Z")
        let logs = [
            RoutineLog(timestamp: makeDate("2026-03-04T10:00:00Z"), taskID: task.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-03-04T10:00:00Z"), taskID: hiddenTask.id, kind: .completed)
        ]
        let focusSessions = [
            FocusSession(
                taskID: task.id,
                startedAt: makeDate("2026-03-04T09:00:00Z"),
                completedAt: makeDate("2026-03-04T09:30:00Z")
            )
        ]

        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [task, hiddenTask],
            logs: logs,
            focusSessions: focusSessions,
            goals: [goal, hiddenGoal],
            selectedRange: .week,
            taskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: ["Launch"],
            includeTagMatchMode: .all,
            excludedTags: [],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(state.metrics.goalProgressChartPoints.count == 1)
        #expect(state.metrics.goalProgressChartPoints.first?.goalID == goal.id)
        #expect(state.metrics.goalProgressChartPoints.first?.linkedTaskCount == 1)
        #expect(state.metrics.goalProgressChartPoints.first?.completedTaskCount == 1)
        #expect(state.metrics.goalProgressChartPoints.first?.completionCount == 1)
        #expect(state.metrics.goalProgressChartPoints.first?.focusSeconds == TimeInterval(30 * 60))
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

    @Test
    func summaryItemsOmitReportsWhenMetricsAreEmpty() {
        let items = StatsSummaryCardItemBuilder.items(
            metrics: StatsFeatureMetrics(),
            selectedRange: .week,
            chartPresentation: StatsChartPresentation(selectedRange: .week, isCompact: false),
            taskTypeFilter: .all,
            filteredTaskCount: 0
        )

        #expect(items.isEmpty)
    }

    @Test
    func summaryItemsIncludeAssumedDoneCardsWhenAssumedMetricsHaveData() {
        var metrics = StatsFeatureMetrics()
        metrics.assumedDoneCount = 2
        metrics.totalAssumedEstimatedMinutes = 75

        let items = StatsSummaryCardItemBuilder.items(
            metrics: metrics,
            selectedRange: .week,
            chartPresentation: StatsChartPresentation(selectedRange: .week, isCompact: false),
            taskTypeFilter: .all,
            filteredTaskCount: 0
        )

        #expect(items.map(\.accessibilityIdentifier) == [
            "stats.summary.assumedDones",
            "stats.summary.assumedEstimatedTime"
        ])
        #expect(items.first { $0.accessibilityIdentifier == "stats.summary.assumedDones" }?.value == "2")
        #expect(items.first { $0.accessibilityIdentifier == "stats.summary.assumedEstimatedTime" }?.value == "1h 15m")
    }

    @Test
    func summaryItemsOnlyIncludeSleepReportsWhenSleepHasData() {
        var metrics = StatsFeatureMetrics()
        metrics.sleepSessionCount = 1
        metrics.completedSleepSessionCount = 1
        metrics.totalSleepSeconds = 7 * 60 * 60
        metrics.sleepActiveDayCount = 1

        let items = StatsSummaryCardItemBuilder.items(
            metrics: metrics,
            selectedRange: .week,
            chartPresentation: StatsChartPresentation(selectedRange: .week, isCompact: false),
            taskTypeFilter: .all,
            filteredTaskCount: 0
        )

        #expect(items.map(\.accessibilityIdentifier) == [
            "stats.summary.sleepTime",
            "stats.summary.sleepSessions"
        ])
    }

    @Test
    func summaryItemsOmitSleepTimeWhenSleepDurationIsZero() {
        var metrics = StatsFeatureMetrics()
        metrics.sleepSessionCount = 1

        let items = StatsSummaryCardItemBuilder.items(
            metrics: metrics,
            selectedRange: .week,
            chartPresentation: StatsChartPresentation(selectedRange: .week, isCompact: false),
            taskTypeFilter: .all,
            filteredTaskCount: 0
        )

        #expect(items.map(\.accessibilityIdentifier) == [
            "stats.summary.sleepSessions"
        ])
    }
}
