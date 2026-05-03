import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskDetailPresentationRoutingSupportTests {
    @Test
    func undoCompletionCopyUsesAdaptiveRemovalTextWhenRemovingSpecificLog() {
        let copy = TaskDetailUndoCompletionAlertCopy.make(
            pendingLogRemovalTimestamp: Date(),
            mode: .adaptiveRemoval
        )

        #expect(copy.title == "Remove log?")
        #expect(copy.actionTitle == "Remove")
        #expect(copy.message == "This will permanently remove this routine log and may update the routine's schedule.")
    }

    @Test
    func undoCompletionCopyUsesCompletionUndoTextWithoutPendingRemoval() {
        let copy = TaskDetailUndoCompletionAlertCopy.make(
            pendingLogRemovalTimestamp: nil,
            mode: .adaptiveRemoval
        )

        #expect(copy.title == "Undo log?")
        #expect(copy.actionTitle == "Undo")
        #expect(copy.message == "This will remove the selected completion log and may update the routine's schedule.")
    }

    @Test
    func undoOnlyCopyKeepsMacLegacyText() {
        let copy = TaskDetailUndoCompletionAlertCopy.make(
            pendingLogRemovalTimestamp: Date(),
            mode: .undoOnly
        )

        #expect(copy.title == "Undo log?")
        #expect(copy.actionTitle == "Undo")
        #expect(copy.message == "This will remove the selected log and may update the routine's schedule.")
    }
}
