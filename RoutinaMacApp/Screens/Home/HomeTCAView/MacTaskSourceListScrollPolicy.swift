import Foundation

enum MacTaskSourceListScrollEvent: Equatable {
    case listAppeared
    case selectionChanged
    case visibleTaskIDsChanged
    case scrollRequestChanged
}

enum MacTaskSourceListScrollPolicy {
    static func scrollTarget(
        for event: MacTaskSourceListScrollEvent,
        selectedTaskID: UUID? = nil,
        pendingRequest: MacSidebarTaskScrollRequest?,
        visibleTaskIDs: [UUID]
    ) -> UUID? {
        switch event {
        case .selectionChanged:
            return nil
        case .listAppeared, .visibleTaskIDsChanged, .scrollRequestChanged:
            guard
                let taskID = pendingRequest?.taskID,
                visibleTaskIDs.contains(taskID)
            else {
                return nil
            }
            return taskID
        }
    }
}
