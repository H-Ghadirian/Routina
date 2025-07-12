import Foundation
import Testing
@testable @preconcurrency import RoutinaAppSupport

struct RoutineDateMathTests {
    @Test
    func elapsedDaysSinceLastDone_usesCalendarDayBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let lastDone = makeDate("2026-03-14T15:00:00Z")
        let referenceDate = makeDate("2026-03-15T10:00:00Z")

        let elapsedDays = RoutineDateMath.elapsedDaysSinceLastDone(
            from: lastDone,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(elapsedDays == 1)
    }

    @Test
    func elapsedDaysSinceLastDone_returnsZeroWhenNoCompletionExists() {
        let elapsedDays = RoutineDateMath.elapsedDaysSinceLastDone(
            from: nil,
            referenceDate: makeDate("2026-03-15T10:00:00Z")
        )

        #expect(elapsedDays == 0)
    }

    @Test
    func dueDate_prefersScheduleAnchorWhenPresent() {
        let task = RoutineTask(
            interval: 7,
            lastDone: makeDate("2026-03-01T10:00:00Z"),
            scheduleAnchor: makeDate("2026-03-04T10:00:00Z")
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-10T10:00:00Z")
        )

        #expect(dueDate == makeDate("2026-03-11T10:00:00Z"))
    }

    @Test
    func dueDate_usesEarliestChecklistItemForChecklistDrivenRoutine() {
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(
                    title: "Bread",
                    intervalDays: 3,
                    lastPurchasedAt: makeDate("2026-03-18T10:00:00Z"),
                    createdAt: makeDate("2026-03-15T10:00:00Z")
                ),
                RoutineChecklistItem(
                    title: "Milk",
                    intervalDays: 5,
                    lastPurchasedAt: makeDate("2026-03-17T10:00:00Z"),
                    createdAt: makeDate("2026-03-15T10:00:00Z")
                )
            ]
        )

        let dueDate = RoutineDateMath.dueDate(
            for: task,
            referenceDate: makeDate("2026-03-20T10:00:00Z")
        )

        #expect(dueDate == makeDate("2026-03-21T10:00:00Z"))
    }

    @Test
    func resumedScheduleAnchor_shiftsByPauseDuration() {
        let task = RoutineTask(
            interval: 7,
            scheduleAnchor: makeDate("2026-03-01T10:00:00Z"),
            pausedAt: makeDate("2026-03-05T10:00:00Z")
        )

        let resumedAnchor = RoutineDateMath.resumedScheduleAnchor(
            for: task,
            resumedAt: makeDate("2026-03-08T10:00:00Z")
        )

        #expect(resumedAnchor == makeDate("2026-03-04T10:00:00Z"))
    }
}
