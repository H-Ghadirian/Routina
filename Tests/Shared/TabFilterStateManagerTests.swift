import Foundation
import Testing
@testable @preconcurrency import RoutinaAppSupport

struct TabFilterStateManagerTests {

    // MARK: - snapshot(for:) default

    @Test
    func snapshot_returnsDefault_whenNoSnapshotSaved() {
        let manager = TabFilterStateManager()
        let snapshot = manager.snapshot(for: "Todos")

        #expect(snapshot.selectedTag == nil)
        #expect(snapshot.excludedTags.isEmpty)
        #expect(snapshot.selectedFilter == .all)
        #expect(snapshot.selectedManualPlaceFilterID == nil)
    }

    // MARK: - hasSnapshot(for:)

    @Test
    func hasSnapshot_returnsFalse_beforeAnySave() {
        let manager = TabFilterStateManager()
        #expect(!manager.hasSnapshot(for: "Todos"))
        #expect(!manager.hasSnapshot(for: "Routines"))
    }

    @Test
    func hasSnapshot_returnsTrue_afterSave() {
        var manager = TabFilterStateManager()
        manager.save(.default, for: "Todos")
        #expect(manager.hasSnapshot(for: "Todos"))
    }

    // MARK: - save / restore round-trip

    @Test
    func saveAndRestore_preservesAllFilterFields() {
        var manager = TabFilterStateManager()
        let placeID = UUID()

        let snapshot = TabFilterStateManager.Snapshot(
            selectedTag: "Work",
            excludedTags: ["Personal", "Health"],
            selectedFilter: .due,
            selectedManualPlaceFilterID: placeID
        )

        manager.save(snapshot, for: "Todos")
        let restored = manager.snapshot(for: "Todos")

        #expect(restored.selectedTag == "Work")
        #expect(restored.excludedTags == ["Personal", "Health"])
        #expect(restored.selectedFilter == .due)
        #expect(restored.selectedManualPlaceFilterID == placeID)
    }

    @Test
    func saveAndRestore_preservesNilFieldsCorrectly() {
        var manager = TabFilterStateManager()

        let snapshot = TabFilterStateManager.Snapshot(
            selectedTag: nil,
            excludedTags: [],
            selectedFilter: .doneToday,
            selectedManualPlaceFilterID: nil
        )

        manager.save(snapshot, for: "Routines")
        let restored = manager.snapshot(for: "Routines")

        #expect(restored.selectedTag == nil)
        #expect(restored.excludedTags.isEmpty)
        #expect(restored.selectedFilter == .doneToday)
        #expect(restored.selectedManualPlaceFilterID == nil)
    }

    // MARK: - Tab isolation

    @Test
    func filtersAreIsolatedPerTab_todoFilterDoesNotAffectRoutines() {
        var manager = TabFilterStateManager()

        let todosSnapshot = TabFilterStateManager.Snapshot(
            selectedTag: "Work",
            excludedTags: ["Personal"],
            selectedFilter: .due,
            selectedManualPlaceFilterID: nil
        )
        manager.save(todosSnapshot, for: "Todos")

        // Routines tab has never had a snapshot saved — should return defaults
        let routinesSnapshot = manager.snapshot(for: "Routines")

        #expect(routinesSnapshot.selectedTag == nil)
        #expect(routinesSnapshot.excludedTags.isEmpty)
        #expect(routinesSnapshot.selectedFilter == .all)
    }

    @Test
    func filtersAreIsolatedPerTab_eachTabHoldsItsOwnState() {
        var manager = TabFilterStateManager()

        let todosSnapshot = TabFilterStateManager.Snapshot(
            selectedTag: "Fitness",
            excludedTags: [],
            selectedFilter: .due,
            selectedManualPlaceFilterID: nil
        )
        let routinesSnapshot = TabFilterStateManager.Snapshot(
            selectedTag: "Home",
            excludedTags: ["Work"],
            selectedFilter: .doneToday,
            selectedManualPlaceFilterID: UUID()
        )

        manager.save(todosSnapshot, for: "Todos")
        manager.save(routinesSnapshot, for: "Routines")

        let restoredTodos = manager.snapshot(for: "Todos")
        let restoredRoutines = manager.snapshot(for: "Routines")

        #expect(restoredTodos.selectedTag == "Fitness")
        #expect(restoredTodos.selectedFilter == .due)

        #expect(restoredRoutines.selectedTag == "Home")
        #expect(restoredRoutines.excludedTags == ["Work"])
        #expect(restoredRoutines.selectedFilter == .doneToday)
    }

    // MARK: - Tab-switching simulation

    @Test
    func switchingTabs_preservesTodosFiltersWhenReturning() {
        var manager = TabFilterStateManager()

        // User is on Todos, applies a tag filter
        let todosFilter = TabFilterStateManager.Snapshot(
            selectedTag: "Work",
            excludedTags: [],
            selectedFilter: .due,
            selectedManualPlaceFilterID: nil
        )

        // Switch away: save Todos snapshot, restore Routines (first visit → defaults)
        manager.save(todosFilter, for: "Todos")
        let routinesOnFirstVisit = manager.snapshot(for: "Routines")
        #expect(routinesOnFirstVisit.selectedTag == nil, "Routines should start with no filter")

        // Apply a different filter on Routines, then switch back to Todos
        let routinesFilter = TabFilterStateManager.Snapshot(
            selectedTag: "Health",
            excludedTags: [],
            selectedFilter: .all,
            selectedManualPlaceFilterID: nil
        )
        manager.save(routinesFilter, for: "Routines")

        // Restore Todos — must get the original filter back
        let restoredTodos = manager.snapshot(for: "Todos")
        #expect(restoredTodos.selectedTag == "Work")
        #expect(restoredTodos.selectedFilter == .due)
    }

    @Test
    func switchingTabs_updatedSnapshotOverwritesPreviousOne() {
        var manager = TabFilterStateManager()

        let firstSnapshot = TabFilterStateManager.Snapshot(
            selectedTag: "Work",
            excludedTags: [],
            selectedFilter: .due,
            selectedManualPlaceFilterID: nil
        )
        manager.save(firstSnapshot, for: "Todos")

        // User switches away and comes back, then changes the filter
        let updatedSnapshot = TabFilterStateManager.Snapshot(
            selectedTag: "Personal",
            excludedTags: ["Work"],
            selectedFilter: .doneToday,
            selectedManualPlaceFilterID: nil
        )
        manager.save(updatedSnapshot, for: "Todos")

        let restored = manager.snapshot(for: "Todos")
        #expect(restored.selectedTag == "Personal")
        #expect(restored.excludedTags == ["Work"])
        #expect(restored.selectedFilter == .doneToday)
    }

    @Test
    func switchingTabs_multipleRoundTripsPreserveEachTabsFilters() {
        var manager = TabFilterStateManager()

        // Round 1: set up both tabs
        manager.save(
            TabFilterStateManager.Snapshot(selectedTag: "A", excludedTags: [], selectedFilter: .due, selectedManualPlaceFilterID: nil),
            for: "Todos"
        )
        manager.save(
            TabFilterStateManager.Snapshot(selectedTag: "B", excludedTags: [], selectedFilter: .doneToday, selectedManualPlaceFilterID: nil),
            for: "Routines"
        )

        // Round 2: switch back and forth several times without changing filters
        for _ in 1...5 {
            #expect(manager.snapshot(for: "Todos").selectedTag == "A")
            #expect(manager.snapshot(for: "Routines").selectedTag == "B")
        }
    }
}
