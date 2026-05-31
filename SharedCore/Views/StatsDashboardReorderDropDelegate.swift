import SwiftUI
import UniformTypeIdentifiers

struct StatsDashboardReorderDropDelegate: DropDelegate {
    static let supportedContentTypes: [UTType] = [.text]

    let itemID: String
    @Binding var draggedItemID: String?
    let orderedItemIDs: [String]
    let onMove: (String, String) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedItemID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItemID,
              draggedItemID != itemID,
              orderedItemIDs.contains(draggedItemID),
              orderedItemIDs.contains(itemID) else {
            return
        }

        onMove(draggedItemID, itemID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItemID = nil
        return true
    }
}
