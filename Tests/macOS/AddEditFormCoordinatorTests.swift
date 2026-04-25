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
        coordinator.scrollTarget = .notes

        coordinator.requestNameFocus()

        #expect(coordinator.scrollTarget == .notes)
        #expect(coordinator.nameFocusRequestID == 1)
    }

    // MARK: - Section ordering

    @Test
    func orderedSections_identityAlwaysFirst() {
        let coordinator = AddEditFormCoordinator()
        let available: [FormSection] = [.identity, .behavior, .tags, .notes]
        let result = coordinator.orderedSections(available: available)

        #expect(result.first == .identity)
    }

    @Test
    func orderedSections_filtersUnavailable() {
        let coordinator = AddEditFormCoordinator()
        let available: [FormSection] = [.identity, .behavior, .tags]
        let result = coordinator.orderedSections(available: available)

        #expect(!result.contains(.steps))
        #expect(!result.contains(.notes))
        #expect(result.contains(.behavior))
        #expect(result.contains(.tags))
    }

    @Test
    func moveUp_swapsWithPreviousSection() {
        let coordinator = AddEditFormCoordinator()
        // Default order starts with .color, .behavior, ...
        let originalSecond = coordinator.sectionOrder[1]
        let originalFirst = coordinator.sectionOrder[0]

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
        let originalFirst = coordinator.sectionOrder[0]
        let originalSecond = coordinator.sectionOrder[1]

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
        // Move .notes to the top
        let notesIndex = coordinator.sectionOrder.firstIndex(of: .notes)!
        for _ in 0..<notesIndex {
            coordinator.moveUp(.notes)
        }

        let available: [FormSection] = [.identity, .behavior, .notes, .tags]
        let result = coordinator.orderedSections(available: available)

        #expect(result == [.identity, .notes, .behavior, .tags])
    }

    @Test
    func orderedSections_appendsUnknownAvailableSections() {
        let coordinator = AddEditFormCoordinator()
        // .dangerZone is not in default movable sections
        let available: [FormSection] = [.identity, .behavior, .dangerZone]
        let result = coordinator.orderedSections(available: available)

        #expect(result.contains(.dangerZone))
        #expect(result.last == .dangerZone)
    }
}
