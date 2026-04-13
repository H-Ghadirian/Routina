import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct AddEditFormCoordinatorTests {
    @Test
    func requestNameFocus_incrementsRequestID() {
        let coordinator = AddEditFormCoordinator()

        #expect(coordinator.nameFocusRequestID == 0)

        coordinator.requestNameFocus()
        #expect(coordinator.nameFocusRequestID == 1)

        coordinator.requestNameFocus()
        #expect(coordinator.nameFocusRequestID == 2)
    }

    @Test
    func requestNameFocus_preservesScrollTarget() {
        let coordinator = AddEditFormCoordinator()
        coordinator.scrollTarget = "Notes"

        coordinator.requestNameFocus()

        #expect(coordinator.scrollTarget == "Notes")
        #expect(coordinator.nameFocusRequestID == 1)
    }
}
