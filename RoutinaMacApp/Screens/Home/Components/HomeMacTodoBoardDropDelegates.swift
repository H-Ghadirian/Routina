import SwiftUI

struct HomeMacTodoBoardCardDropDelegate: DropDelegate {
    let destinationTaskID: UUID
    let columnState: TodoState
    let orderedTaskIDs: [UUID]
    @Binding var draggedTaskID: UUID?
    @Binding var highlightedColumnState: TodoState?
    @Binding var hoverTargetTaskID: UUID?
    @Binding var trailingDropColumnState: TodoState?
    let onDropTask: (UUID, TodoState, [UUID]) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedTaskID != nil
    }

    func dropEntered(info: DropInfo) {
        highlightedColumnState = columnState
        hoverTargetTaskID = destinationTaskID
        trailingDropColumnState = nil
    }

    func dropExited(info: DropInfo) {
        if highlightedColumnState == columnState {
            highlightedColumnState = nil
        }
        if hoverTargetTaskID == destinationTaskID {
            hoverTargetTaskID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            clearDragState()
        }

        guard let draggedTaskID,
              draggedTaskID != destinationTaskID,
              let destinationIndex = orderedTaskIDs.firstIndex(of: destinationTaskID) else {
            return false
        }

        let reorderedIDs = reorderedTaskIDs(
            draggedTaskID: draggedTaskID,
            destinationIndex: destinationIndex,
            orderedTaskIDs: orderedTaskIDs
        )
        onDropTask(draggedTaskID, columnState, reorderedIDs)
        return true
    }

    private func reorderedTaskIDs(
        draggedTaskID: UUID,
        destinationIndex: Int,
        orderedTaskIDs: [UUID]
    ) -> [UUID] {
        var result = orderedTaskIDs.filter { $0 != draggedTaskID }
        let boundedIndex = min(max(destinationIndex, 0), result.count)
        result.insert(draggedTaskID, at: boundedIndex)
        return result
    }

    private func clearDragState() {
        highlightedColumnState = nil
        hoverTargetTaskID = nil
        trailingDropColumnState = nil
        draggedTaskID = nil
    }
}

struct HomeMacTodoBoardColumnDropDelegate: DropDelegate {
    let columnState: TodoState
    let orderedTaskIDs: [UUID]
    @Binding var draggedTaskID: UUID?
    @Binding var highlightedColumnState: TodoState?
    @Binding var hoverTargetTaskID: UUID?
    @Binding var trailingDropColumnState: TodoState?
    let onDropTask: (UUID, TodoState, [UUID]) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedTaskID != nil
    }

    func dropEntered(info: DropInfo) {
        highlightedColumnState = columnState
        hoverTargetTaskID = nil
        trailingDropColumnState = columnState
    }

    func dropExited(info: DropInfo) {
        if highlightedColumnState == columnState {
            highlightedColumnState = nil
        }
        if trailingDropColumnState == columnState {
            trailingDropColumnState = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            clearDragState()
        }

        guard let draggedTaskID else { return false }
        var reorderedIDs = orderedTaskIDs.filter { $0 != draggedTaskID }
        reorderedIDs.append(draggedTaskID)
        onDropTask(draggedTaskID, columnState, reorderedIDs)
        return true
    }

    private func clearDragState() {
        highlightedColumnState = nil
        hoverTargetTaskID = nil
        trailingDropColumnState = nil
        draggedTaskID = nil
    }
}
