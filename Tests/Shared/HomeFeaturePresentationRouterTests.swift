import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct HomeFeaturePresentationRouterTests {
    @Test
    func requestDeleteTasksDeduplicatesAndPresentsConfirmation() {
        let firstID = UUID()
        let secondID = UUID()
        var state = TestPresentationRoutingState()

        HomeFeaturePresentationRouter().requestDeleteTasks([firstID, secondID, firstID], state: &state)

        #expect(state.presentation.pendingDeleteTaskIDs == [firstID, secondID])
        #expect(state.presentation.isDeleteConfirmationPresented)
    }

    @Test
    func cancelDeleteConfirmationClearsPendingIDs() {
        let taskID = UUID()
        var state = TestPresentationRoutingState(
            presentation: HomePresentationState(
                pendingDeleteTaskIDs: [taskID],
                isDeleteConfirmationPresented: true
            )
        )

        HomeFeaturePresentationRouter().setDeleteConfirmation(false, state: &state)

        #expect(state.presentation.pendingDeleteTaskIDs.isEmpty)
        #expect(!state.presentation.isDeleteConfirmationPresented)
    }

    @Test
    func consumePendingDeleteTaskIDsReturnsAndClearsPendingIDs() {
        let taskID = UUID()
        var state = TestPresentationRoutingState(
            presentation: HomePresentationState(
                pendingDeleteTaskIDs: [taskID],
                isDeleteConfirmationPresented: true
            )
        )

        let consumedIDs = HomeFeaturePresentationRouter().consumePendingDeleteTaskIDs(state: &state)

        #expect(consumedIDs == [taskID])
        #expect(state.presentation.pendingDeleteTaskIDs.isEmpty)
        #expect(!state.presentation.isDeleteConfirmationPresented)
    }

    @Test
    func showingFilterDetailClosesAddSheetAndClearsSelectionIdentity() {
        let taskID = UUID()
        var state = TestPresentationRoutingState(
            selection: HomeSelectionState(selectedTaskID: taskID),
            presentation: HomePresentationState(
                isAddRoutineSheetPresented: true,
                addRoutineState: AddRoutineFeature.State()
            )
        )

        HomeFeaturePresentationRouter().setFilterDetailPresented(true, state: &state)

        #expect(state.presentation.isMacFilterDetailPresented)
        #expect(!state.presentation.isAddRoutineSheetPresented)
        #expect(state.presentation.addRoutineState == nil)
        #expect(state.selection.selectedTaskID == nil)
    }
}

private struct TestPresentationRoutingState: HomeFeaturePresentationRoutingState, Equatable {
    var selection = HomeSelectionState()
    var presentation = HomePresentationState()
}
