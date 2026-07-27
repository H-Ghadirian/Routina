import Foundation

enum MacTaskSourceListScrollEvent: Equatable {
    case listAppeared
    case selectionChanged
    case visibleTaskIDsChanged
    case scrollRequestChanged
}

enum MacTaskSourceListScrollStep: Equatable {
    case section(String)
    case group(sectionID: String, groupID: String)
    case task(UUID)
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

    static func stagedScrollSteps(
        for request: MacSidebarTaskScrollRequest
    ) -> [MacTaskSourceListScrollStep] {
        var steps: [MacTaskSourceListScrollStep] = []
        if let destination = request.destination {
            steps.append(.section(destination.sectionID))
            steps.append(
                contentsOf: destination.groupIDs.map {
                    .group(sectionID: destination.sectionID, groupID: $0)
                }
            )
        }
        steps.append(.task(request.taskID))
        return steps
    }
}

enum MacTaskSourceListScrollPreservation {
    static let animatesUserDrivenDisclosureChanges = false

    static func verticalOrigin(
        preserving requestedOrigin: CGFloat,
        documentHeight: CGFloat,
        viewportHeight: CGFloat
    ) -> CGFloat {
        min(max(0, requestedOrigin), max(0, documentHeight - viewportHeight))
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
