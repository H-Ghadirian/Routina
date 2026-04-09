import Testing
@testable @preconcurrency import RoutinaAppSupport

struct RoutinePauseArchivePresentationTests {
    @Test
    func pauseActionTitle_tracksArchivedState() {
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: false, context: .detail).actionTitle
                == "Pause Routine"
        )
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: true, context: .detail).actionTitle
                == "Resume Routine"
        )
    }

    @Test
    func detailPresentation_onlyShowsPausedExplanation() {
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: false, context: .detail).description
                == nil
        )
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: true, context: .detail).description
                == "Archived routines stay out of the main list and won't send reminders until resumed."
        )
    }

    @Test
    func editSheetPresentation_explainsArchiveTransitions() {
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: false, context: .editSheet).description
                == "Pausing moves this routine into the archived list, hides it from the main list, and stops notifications."
        )
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: true, context: .editSheet).description
                == "This routine is archived right now. Resume it to bring it back to the main list and notifications."
        )
    }
}
