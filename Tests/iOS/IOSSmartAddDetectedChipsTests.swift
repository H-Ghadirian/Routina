import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct IOSSmartAddDetectedChipsTests {
    @Test
    func exactDateAndTimeAvailabilityIsShownAsDetected() throws {
        let calendar = makeTestCalendar()
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Physiotherapist Tuesday, 25 August 15:00",
            referenceDate: makeDate("2026-08-20T10:00:00Z"),
            calendar: calendar
        ))
        let expectedDate = try #require(draft.exactAvailabilityDate(calendar: calendar))

        let rows = IOSSmartAddDetectedChips.detectedDetailRows(
            for: draft,
            calendar: calendar
        )
        let available = try #require(rows.first { $0.title == "Available" })

        #expect(available.value == "One-time task at \(expectedDate.formatted(date: .abbreviated, time: .shortened))")
        #expect(available.systemImage == "calendar")
        #expect(IOSSmartAddDetectedChips.hasDetections(in: draft))
    }
}
