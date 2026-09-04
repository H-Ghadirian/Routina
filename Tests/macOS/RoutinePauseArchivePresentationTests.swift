import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct RoutinePauseArchivePresentationTests {
    @Test
    func pauseActionTitle_tracksArchivedState() {
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: false, context: .detail).actionTitle
                == "Pause Repeating Task"
        )
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: true, context: .detail).actionTitle
                == "Resume Repeating Task"
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
                == "Archived repeating tasks stay out of the main list and won't send reminders until resumed."
        )
    }

    @Test
    func editSheetPresentation_explainsArchiveTransitions() {
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: false, context: .editSheet).description
                == "Pausing moves this repeating task into the archived list, hides it from the main list, and stops notifications."
        )
        #expect(
            RoutinePauseArchivePresentation.make(isPaused: true, context: .editSheet).description
                == "This repeating task is archived right now. Resume it to bring it back to the main list and notifications."
        )
    }
}
