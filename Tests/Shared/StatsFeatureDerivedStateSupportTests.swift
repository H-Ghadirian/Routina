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
}
