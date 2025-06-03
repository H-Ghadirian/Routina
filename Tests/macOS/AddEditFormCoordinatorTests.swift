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

    // MARK: - Section ordering

    @Test
    func orderedSections_identityAlwaysFirst() {
        let coordinator = AddEditFormCoordinator()
        let available = ["Identity", "Behavior", "Tags", "Notes"]
        let result = coordinator.orderedSections(available: available)

        #expect(result.first == "Identity")
    }

    @Test
    func orderedSections_filtersUnavailable() {
        let coordinator = AddEditFormCoordinator()
        let available = ["Identity", "Behavior", "Tags"]
        let result = coordinator.orderedSections(available: available)

        #expect(!result.contains("Steps"))
        #expect(!result.contains("Notes"))
        #expect(result.contains("Behavior"))
        #expect(result.contains("Tags"))
    }

    @Test
    func moveUp_swapsWithPreviousSection() {
        let coordinator = AddEditFormCoordinator()
        // Default order starts with Behavior, Places, ...
        let originalSecond = coordinator.sectionOrder[1] // Places
        let originalFirst = coordinator.sectionOrder[0]  // Behavior

        coordinator.moveUp(originalSecond)

        #expect(coordinator.sectionOrder[0] == originalSecond)
        #expect(coordinator.sectionOrder[1] == originalFirst)
    }

    @Test
    func moveUp_firstElement_doesNothing() {
        let coordinator = AddEditFormCoordinator()
        let first = coordinator.sectionOrder[0]

        coordinator.moveUp(first)

        #expect(coordinator.sectionOrder[0] == first)
    }

    @Test
    func moveDown_swapsWithNextSection() {
        let coordinator = AddEditFormCoordinator()
        let originalFirst = coordinator.sectionOrder[0]  // Behavior
        let originalSecond = coordinator.sectionOrder[1] // Places

        coordinator.moveDown(originalFirst)

        #expect(coordinator.sectionOrder[0] == originalSecond)
        #expect(coordinator.sectionOrder[1] == originalFirst)
    }

    @Test
    func moveDown_lastElement_doesNothing() {
        let coordinator = AddEditFormCoordinator()
        let last = coordinator.sectionOrder.last!

        coordinator.moveDown(last)

        #expect(coordinator.sectionOrder.last == last)
    }

    @Test
    func orderedSections_respectsCustomOrder() {
        let coordinator = AddEditFormCoordinator()
        // Move "Notes" to the top
        let notesIndex = coordinator.sectionOrder.firstIndex(of: "Notes")!
        for _ in 0..<notesIndex {
            coordinator.moveUp("Notes")
        }

        let available = ["Identity", "Behavior", "Notes", "Tags"]
        let result = coordinator.orderedSections(available: available)

        #expect(result == ["Identity", "Notes", "Behavior", "Tags"])
    }

    @Test
    func orderedSections_appendsUnknownAvailableSections() {
        let coordinator = AddEditFormCoordinator()
        // "Danger Zone" is not in default movable sections
        let available = ["Identity", "Behavior", "Danger Zone"]
        let result = coordinator.orderedSections(available: available)

        #expect(result.contains("Danger Zone"))
        #expect(result.last == "Danger Zone")
    }
}
