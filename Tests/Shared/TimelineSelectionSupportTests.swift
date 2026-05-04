import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TimelineSelectionSupportTests {
    @Test
    func resolvedSelectionPreservesPhoneSelection() {
        let selected = UUID()
        #expect(
            TimelineSelectionSupport.resolvedSelection(
                currentSelection: selected,
                visibleEntryIDs: [],
                usesSidebarLayout: false
            ) == selected
        )
    }

    @Test
    func resolvedSelectionKeepsVisibleSidebarSelectionOrFallsBackToFirstVisibleEntry() {
        let first = UUID()
        let second = UUID()
        let missing = UUID()

        #expect(
            TimelineSelectionSupport.resolvedSelection(
                currentSelection: second,
                visibleEntryIDs: [first, second],
                usesSidebarLayout: true
            ) == second
        )
        #expect(
            TimelineSelectionSupport.resolvedSelection(
                currentSelection: missing,
                visibleEntryIDs: [first, second],
                usesSidebarLayout: true
            ) == first
        )
    }
}
