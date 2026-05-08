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
