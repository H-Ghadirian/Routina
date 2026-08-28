import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct StatsSummaryTaskListPresentationTests {
    @Test
    func taskBackedSummaryIdentifiersResolveToPopoverKinds() {
        let identifiers = [
            "stats.hero.activities",
            "stats.summary.dailyAverage",
            "stats.summary.bestDay",
            "stats.summary.focusTime",
            "stats.summary.focusAverage",
            "stats.summary.totalDones",
            "stats.summary.assumedDones",
            "stats.summary.assumedEstimatedTime",
            "stats.summary.totalCancels",
            "stats.summary.totalMissed",
            "stats.summary.routineCount",
            "stats.summary.todoCount",
            "stats.summary.activeRoutines",
            "stats.summary.archivedRoutines"
        ]

        #expect(identifiers.allSatisfy {
            StatsSummaryTaskListKind(summaryAccessibilityIdentifier: $0) != nil
        })
        #expect(
            StatsSummaryTaskListKind(
                summaryAccessibilityIdentifier: "stats.summary.sleepTime"
            ) == nil
        )
    }

    @Test
    func activityPresentationGroupsOutcomesByFilteredTaskWithinCustomRange() throws {
        let calendar = makeTestCalendar()
        let first = RoutineTask(name: "Alpha", createdAt: makeDate("2026-06-01T08:00:00Z"))
        let second = RoutineTask(name: "Beta", createdAt: makeDate("2026-06-01T08:00:00Z"))
        let filteredOut = RoutineTask(name: "Hidden", createdAt: makeDate("2026-06-01T08:00:00Z"))
        let range = DoneChartRange.custom(
            from: makeDate("2026-06-08T00:00:00Z"),
            through: makeDate("2026-06-09T00:00:00Z"),
            calendar: calendar
        )
        let logs = [
            RoutineLog(timestamp: makeDate("2026-06-08T09:00:00Z"), taskID: first.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-06-09T09:00:00Z"), taskID: first.id, kind: .missed),
            RoutineLog(timestamp: makeDate("2026-06-09T10:00:00Z"), taskID: second.id, kind: .canceled),
            RoutineLog(timestamp: makeDate("2026-06-10T09:00:00Z"), taskID: second.id, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-06-08T09:00:00Z"), taskID: filteredOut.id, kind: .completed)
        ]

        let presentation = StatsSummaryTaskListPresentationBuilder.build(
            kind: .activityOverview,
            cardTitle: "Activities logged",
            tasks: [first, second, filteredOut],
            filteredTaskIDs: [first.id, second.id],
            logs: logs,
            metrics: StatsFeatureMetrics(),
            selectedRange: range,
            referenceDate: range.referenceDate(relativeTo: makeDate("2026-06-20T10:00:00Z")),
            calendar: calendar
        )

        #expect(presentation.subtitle.contains("3 activities across 2 tasks"))
        #expect(presentation.rows.map(\.title) == ["Alpha", "Beta"])
        #expect(presentation.rows.map(\.value) == ["2×", "1×"])
        #expect(presentation.rows[0].detail == "1 done · 1 missed")
        #expect(presentation.rows[1].detail == "1 canceled")
    }

    @Test
    func assumedPresentationsGroupOccurrencesAndOnlyTimeContributors() throws {
        let calendar = makeTestCalendar()
        let hydrate = RoutineTask(
            name: "Hydrate",
            scheduleMode: .softInterval,
            recurrenceRule: .interval(days: 1),
            createdAt: makeDate("2026-05-07T08:00:00Z"),
            autoAssumeDailyDone: true,
            estimatedDurationMinutes: 10
        )
        let stretch = RoutineTask(
            name: "Stretch",
            scheduleMode: .softInterval,
            recurrenceRule: .interval(days: 1),
            createdAt: makeDate("2026-05-09T08:00:00Z"),
            autoAssumeDailyDone: true
        )
        let referenceDate = makeDate("2026-05-09T10:00:00Z")
        let logs = [
            RoutineLog(
                timestamp: makeDate("2026-05-08T10:00:00Z"),
                taskID: hydrate.id,
                kind: .completed
            )
        ]

        let assumed = StatsSummaryTaskListPresentationBuilder.build(
            kind: .assumedDones,
            cardTitle: "Assumed done",
            tasks: [hydrate, stretch],
            filteredTaskIDs: [hydrate.id, stretch.id],
            logs: logs,
            metrics: StatsFeatureMetrics(),
            selectedRange: .week,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let assumedTime = StatsSummaryTaskListPresentationBuilder.build(
            kind: .assumedEstimatedTime,
            cardTitle: "Assumed time",
            tasks: [hydrate, stretch],
            filteredTaskIDs: [hydrate.id, stretch.id],
            logs: logs,
            metrics: StatsFeatureMetrics(),
            selectedRange: .week,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(assumed.subtitle.contains("3 assumed occurrences across 2 tasks"))
        #expect(assumed.rows.map(\.title) == ["Hydrate", "Stretch"])
        #expect(assumed.rows.map(\.value) == ["2×", "1×"])
        #expect(assumedTime.subtitle.contains("20m across 1 task"))
        #expect(assumedTime.rows.map(\.title) == ["Hydrate"])
        #expect(assumedTime.rows.map(\.value) == ["20m"])
    }

    @Test
    func focusPresentationAggregatesTaskAndNonTaskSourcesAcrossChartPoints() throws {
        let task = RoutineTask(name: "Write", createdAt: makeDate("2026-05-01T08:00:00Z"))
        var metrics = StatsFeatureMetrics()
        metrics.totalFocusSeconds = 35 * 60
        metrics.focusChartPoints = [
            FocusDurationChartPoint(
                date: makeDate("2026-05-08T00:00:00Z"),
                seconds: 25 * 60,
                contributions: [
                    FocusDurationContribution(taskID: task.id, title: "Write", seconds: 20 * 60, sessionCount: 1),
                    FocusDurationContribution(taskID: nil, title: "Unassigned focus", seconds: 5 * 60, sessionCount: 1)
                ]
            ),
            FocusDurationChartPoint(
                date: makeDate("2026-05-09T00:00:00Z"),
                seconds: 10 * 60,
                contributions: [
                    FocusDurationContribution(taskID: task.id, title: "Write", seconds: 10 * 60, sessionCount: 1)
                ]
            )
        ]

        let presentation = StatsSummaryTaskListPresentationBuilder.build(
            kind: .focusTime,
            cardTitle: "Focus time",
            tasks: [task],
            filteredTaskIDs: [task.id],
            logs: [],
            metrics: metrics,
            selectedRange: .week,
            referenceDate: makeDate("2026-05-09T10:00:00Z"),
            calendar: makeTestCalendar()
        )

        #expect(presentation.subtitle.contains("35m across 2 focus sources"))
        #expect(presentation.rows.map(\.title) == ["Write", "Unassigned focus"])
        #expect(presentation.rows.map(\.value) == ["30m", "5m"])
        #expect(presentation.rows[0].detail == "2 focus sessions")
    }
}
