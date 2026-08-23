import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskDetailMacTimeControlPresentationTests {
    @Test
    func todoEffortMetadataStillPresentsTheCombinedHeaderBox() {
        #expect(
            !TaskDetailMacTimeControlPresentation.showsAddAction(
                for: .todo,
                isTimeControlVisible: false,
                hasEffortMetadata: true
            )
        )
        #expect(
            TaskDetailMacTimeControlPresentation.showsHeaderBox(
                for: .todo,
                isTimeControlVisible: false,
                hasEffortMetadata: true
            )
        )
    }

    @Test
    func routineDoesNotExposeTaskLevelTimeControl() {
        #expect(!TaskDetailMacTimeControlPresentation.canShowTimeControl(for: .routine))
        #expect(
            !TaskDetailMacTimeControlPresentation.showsAddAction(
                for: .routine,
                isTimeControlVisible: true,
                hasEffortMetadata: true
            )
        )
        #expect(
            !TaskDetailMacTimeControlPresentation.showsHeaderBox(
                for: .routine,
                isTimeControlVisible: true,
                hasEffortMetadata: true
            )
        )
    }
}
