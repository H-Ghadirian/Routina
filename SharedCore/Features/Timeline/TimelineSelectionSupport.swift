import Foundation

enum TimelineSelectionSupport {
    static func resolvedSelection(
        currentSelection: UUID?,
        visibleEntryIDs: [UUID],
        usesSidebarLayout: Bool,
        allowsFallbackSelection: Bool = true
    ) -> UUID? {
        guard usesSidebarLayout else { return currentSelection }
        if let currentSelection, visibleEntryIDs.contains(currentSelection) {
            return currentSelection
        }
        guard allowsFallbackSelection else { return nil }
        return visibleEntryIDs.first
    }
}
