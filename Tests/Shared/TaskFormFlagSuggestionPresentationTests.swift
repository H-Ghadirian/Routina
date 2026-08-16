import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskFormFlagSuggestionPresentationTests {
    @Test
    func collapsedSuggestionsAreBoundedAndExpandedSuggestionsPreserveEveryFlag() {
        let flags = ["Tracking", "Private", "Focus", "Work", "Personal", "Deferred", "Quiet"]

        #expect(
            TaskFormFlagSuggestionPresentation.visibleAvailableFlags(flags, showsAll: false)
                == Array(flags.prefix(TaskFormFlagSuggestionPresentation.collapsedLimit))
        )
        #expect(TaskFormFlagSuggestionPresentation.visibleAvailableFlags(flags, showsAll: true) == flags)
    }

    @Test
    func assignedOrDefinedFlagsPopulateTheCombinedTagFlagSection() {
        #expect(
            TaskFormTagFlagSectionPresentation.hasContent(
                routineTags: [],
                tagDraft: "",
                routineFlags: ["Tracking"],
                availableFlags: [],
                flagDraft: ""
            )
        )
        #expect(
            TaskFormTagFlagSectionPresentation.hasContent(
                routineTags: [],
                tagDraft: "",
                routineFlags: [],
                availableFlags: ["Tracking"],
                flagDraft: ""
            )
        )
        #expect(
            !TaskFormTagFlagSectionPresentation.hasContent(
                routineTags: [],
                tagDraft: "  ",
                routineFlags: [],
                availableFlags: [],
                flagDraft: "\n"
            )
        )
    }
}
