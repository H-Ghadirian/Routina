import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum HomeMacTodoBoardDragPayload {
    private static let boardTaskType = UTType(exportedAs: "app.routina.todo-board-task")

    static let supportedContentTypes: [UTType] = [
        boardTaskType,
        .plainText,
        .text,
    ]

    static func itemProvider(for taskID: UUID) -> NSItemProvider {
        let provider = NSItemProvider(object: taskID.uuidString as NSString)
        provider.registerDataRepresentation(
            forTypeIdentifier: boardTaskType.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(taskID.uuidString.data(using: .utf8), nil)
            return nil
        }
        return provider
    }

    static func hasTaskPayload(in info: DropInfo) -> Bool {
        info.hasItemsConforming(to: supportedContentTypes)
    }

    @discardableResult
    static func loadTaskID(from info: DropInfo, completion: @escaping @Sendable (UUID?) -> Void) -> Bool {
        if let provider = info.itemProviders(for: [boardTaskType]).first {
            provider.loadDataRepresentation(forTypeIdentifier: boardTaskType.identifier) { data, _ in
                guard
                    let data,
                    let text = String(data: data, encoding: .utf8)
                else {
                    completion(nil)
                    return
                }
                completion(taskID(from: text))
            }
            return true
        }

        guard let provider = info.itemProviders(for: [.plainText, .text]).first else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? NSString else {
                completion(nil)
                return
            }
            completion(taskID(from: text as String))
        }
        return true
    }

    private static func taskID(from text: String) -> UUID? {
        UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

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
        draggedTaskID != nil || HomeMacTodoBoardDragPayload.hasTaskPayload(in: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        validateDrop(info: info) ? DropProposal(operation: .move) : nil
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
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
        guard let destinationIndex = orderedTaskIDs.firstIndex(of: destinationTaskID) else {
            clearDragState()
            return false
        }

        if let draggedTaskID {
            return performDrop(draggedTaskID: draggedTaskID, destinationIndex: destinationIndex)
        }

        let didStartLoading = HomeMacTodoBoardDragPayload.loadTaskID(from: info) { taskID in
            DispatchQueue.main.async {
                guard let taskID else {
                    clearDragState()
                    return
                }
                _ = performDrop(draggedTaskID: taskID, destinationIndex: destinationIndex)
            }
        }
        if !didStartLoading {
            clearDragState()
        }
        return didStartLoading
    }

    private func performDrop(draggedTaskID: UUID, destinationIndex: Int) -> Bool {
        defer {
            clearDragState()
        }

        guard draggedTaskID != destinationTaskID else {
            return false
        }

        let reorderedIDs = Self.reorderedTaskIDs(
            draggedTaskID: draggedTaskID,
            destinationIndex: destinationIndex,
            orderedTaskIDs: orderedTaskIDs
        )
        onDropTask(draggedTaskID, columnState, reorderedIDs)
        return true
    }

    static func reorderedTaskIDs(
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
        draggedTaskID != nil || HomeMacTodoBoardDragPayload.hasTaskPayload(in: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        validateDrop(info: info) ? DropProposal(operation: .move) : nil
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
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
        if let draggedTaskID {
            performDrop(draggedTaskID: draggedTaskID)
            return true
        }

        let didStartLoading = HomeMacTodoBoardDragPayload.loadTaskID(from: info) { taskID in
            DispatchQueue.main.async {
                guard let taskID else {
                    clearDragState()
                    return
                }
                performDrop(draggedTaskID: taskID)
            }
        }
        if !didStartLoading {
            clearDragState()
        }
        return didStartLoading
    }

    private func performDrop(draggedTaskID: UUID) {
        defer {
            clearDragState()
        }

        var reorderedIDs = orderedTaskIDs.filter { $0 != draggedTaskID }
        reorderedIDs.append(draggedTaskID)
        onDropTask(draggedTaskID, columnState, reorderedIDs)
    }

    private func clearDragState() {
        highlightedColumnState = nil
        hoverTargetTaskID = nil
        trailingDropColumnState = nil
        draggedTaskID = nil
    }
}
