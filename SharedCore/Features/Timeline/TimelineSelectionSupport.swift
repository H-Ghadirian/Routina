import Foundation

enum TimelineSelectionSupport {
    static func resolvedSelection(
        currentSelection: UUID?,
        visibleEntryIDs: [UUID],
        usesSidebarLayout: Bool
    ) -> UUID? {
        guard usesSidebarLayout else { return currentSelection }
        if let currentSelection, visibleEntryIDs.contains(currentSelection) {
            return currentSelection
        }
        return visibleEntryIDs.first
    }
}
