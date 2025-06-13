import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@Suite
struct TagCounterFormattingTests {
    @Test
    func chipTitle_supportsAllDisplayModes() {
        let summary = RoutineTagSummary(name: "Focus", linkedRoutineCount: 2, doneCount: 7)

        #expect(
            TagCounterFormatting.chipTitle(
                tag: "Focus",
                summary: summary,
                mode: .none
            ) == "#Focus"
        )
        #expect(
            TagCounterFormatting.chipTitle(
                tag: "Focus",
                summary: summary,
                mode: .linkedAndDone
            ) == "#Focus 2t 7d"
        )
        #expect(
            TagCounterFormatting.chipTitle(
                tag: "Focus",
                summary: summary,
                mode: .combinedTotal
            ) == "#Focus 9"
        )
        #expect(
            TagCounterFormatting.chipTitle(
                tag: "Focus",
                summary: summary,
                mode: .linkedOnly
            ) == "#Focus 2"
        )
        #expect(
            TagCounterFormatting.chipTitle(
                tag: "Focus",
                summary: summary,
                mode: .doneOnly
            ) == "#Focus 7"
        )
    }
}
