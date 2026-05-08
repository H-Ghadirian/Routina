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

enum MacTaskSourceListKeyboardDirection: Equatable {
    case previous
    case next
}

enum MacTaskSourceListKeyboardNavigation {
    static func adjacentTaskID(
        from selectedTaskID: UUID?,
        direction: MacTaskSourceListKeyboardDirection,
        visibleTaskIDs: [UUID]
    ) -> UUID? {
        guard !visibleTaskIDs.isEmpty else { return nil }

        guard
            let selectedTaskID,
            let selectedIndex = visibleTaskIDs.firstIndex(of: selectedTaskID)
        else {
            switch direction {
            case .previous:
                return visibleTaskIDs.last
            case .next:
                return visibleTaskIDs.first
            }
        }

        switch direction {
        case .previous:
            guard selectedIndex > visibleTaskIDs.startIndex else { return nil }
            return visibleTaskIDs[visibleTaskIDs.index(before: selectedIndex)]

        case .next:
            let nextIndex = visibleTaskIDs.index(after: selectedIndex)
            guard nextIndex < visibleTaskIDs.endIndex else { return nil }
            return visibleTaskIDs[nextIndex]
        }
    }
}
