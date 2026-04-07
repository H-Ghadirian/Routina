import Foundation

/// Stores and restores per-tab filter state so that switching between
/// the Routines and Todos tabs doesn't wipe filters the user already set.
struct TabFilterStateManager {

    struct Snapshot: Equatable {
        var selectedTag: String?
        var excludedTags: Set<String>
        var selectedFilter: RoutineListFilter
        var selectedManualPlaceFilterID: UUID?

        static var `default`: Snapshot {
            Snapshot(
                selectedTag: nil,
                excludedTags: [],
                selectedFilter: .all,
                selectedManualPlaceFilterID: nil
            )
        }
    }

    private var snapshots: [String: Snapshot] = [:]

    /// Saves the current filter state for `tabKey`, overwriting any previous snapshot.
    mutating func save(_ snapshot: Snapshot, for tabKey: String) {
        snapshots[tabKey] = snapshot
    }

    /// Returns the previously saved snapshot for `tabKey`, or `.default` if none exists.
    func snapshot(for tabKey: String) -> Snapshot {
        snapshots[tabKey] ?? .default
    }

    /// Returns true when a snapshot has been previously saved for `tabKey`.
    func hasSnapshot(for tabKey: String) -> Bool {
        snapshots[tabKey] != nil
    }
}
