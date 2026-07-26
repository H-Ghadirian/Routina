import Testing
#if SWIFT_PACKAGE
@testable import RoutinaAppSupport
#elseif os(macOS)
@testable import RoutinaMacOSDev
#else
@testable import Routina
#endif

struct RecurrenceSelectionPolicyTests {
    @Test
    func selectionSupportsMultipleOrderedValues() {
        let selected = RecurrenceSelectionPolicy.updating(
            value: 15,
            isSelected: true,
            selection: [31, 1],
            validRange: 1...31
        )

        #expect(selected == [1, 15, 31])
    }

    @Test
    func selectionCannotRemoveItsLastValue() {
        let selected = RecurrenceSelectionPolicy.updating(
            value: 4,
            isSelected: false,
            selection: [4],
            validRange: 1...7
        )

        #expect(selected == [4])
    }

    @Test
    func selectionDropsInvalidStoredValues() {
        let selected = RecurrenceSelectionPolicy.updating(
            value: 6,
            isSelected: true,
            selection: [-1, 2, 99],
            validRange: 1...7
        )

        #expect(selected == [2, 6])
    }

    @Test
    func adaptiveMonthDaysAreVisuallyClassifiable() {
        #expect(!RecurrenceSelectionPolicy.isAdaptiveMonthDay(28))
        #expect(RecurrenceSelectionPolicy.isAdaptiveMonthDay(29))
        #expect(RecurrenceSelectionPolicy.isAdaptiveMonthDay(30))
        #expect(RecurrenceSelectionPolicy.isAdaptiveMonthDay(31))
    }
}
