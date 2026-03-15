import Foundation
import Testing
@testable @preconcurrency import Routina

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
}
