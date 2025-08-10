import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct CalendarTaskImportSupportTests {
    @Test
    func displayNotes_hidesCalendarEventIdentifier() {
        let notes = """
        Imported from Deutsche Feiertage.
        Calendar event: 3DE17037-44AD-4645-94A7-4B9A93139413:51a09fef-525c-3b76-85db-5934055bc9e7
        """

        #expect(CalendarTaskImportSupport.displayNotes(from: notes) == "Imported from Deutsche Feiertage.")
    }

    @Test
    func displayNotes_returnsNilWhenOnlyInternalMarkerRemains() {
        #expect(CalendarTaskImportSupport.displayNotes(from: "Calendar event: event-id") == nil)
    }

    @Test
    func displayEmoji_mapsLegacySystemSymbolToCalendarEmoji() {
        #expect(CalendarTaskImportSupport.displayEmoji(for: "calendar.badge.plus") == CalendarTaskImportSupport.defaultTaskEmoji)
        #expect(CalendarTaskImportSupport.displayEmoji(for: "✅") == "✅")
    }
}
