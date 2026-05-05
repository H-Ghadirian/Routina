import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct MacTaskSourceListScrollPolicyTests {
    @Test
    func selectionChangeDoesNotScrollTaskSourceList() {
        let taskID = UUID()

        let target = MacTaskSourceListScrollPolicy.scrollTarget(
            for: .selectionChanged,
            selectedTaskID: taskID,
            pendingRequest: nil,
            visibleTaskIDs: [taskID]
        )

        #expect(target == nil)
    }

    @Test
    func explicitScrollRequestRevealsVisibleTask() {
        let taskID = UUID()
        let request = MacSidebarTaskScrollRequest(taskID: taskID)

        let target = MacTaskSourceListScrollPolicy.scrollTarget(
            for: .scrollRequestChanged,
            pendingRequest: request,
            visibleTaskIDs: [taskID]
        )

        #expect(target == taskID)
    }

    @Test
    func pendingScrollRequestWaitsForTaskToBecomeVisible() {
        let taskID = UUID()
        let request = MacSidebarTaskScrollRequest(taskID: taskID)

        let hiddenTarget = MacTaskSourceListScrollPolicy.scrollTarget(
            for: .scrollRequestChanged,
            pendingRequest: request,
            visibleTaskIDs: []
        )
        let visibleTarget = MacTaskSourceListScrollPolicy.scrollTarget(
            for: .visibleTaskIDsChanged,
            pendingRequest: request,
            visibleTaskIDs: [taskID]
        )

        #expect(hiddenTarget == nil)
        #expect(visibleTarget == taskID)
    }

    @Test
    func repeatedRequestsForSameTaskRemainDistinct() {
        let taskID = UUID()

        let firstRequest = MacSidebarTaskScrollRequest(taskID: taskID)
        let secondRequest = MacSidebarTaskScrollRequest(taskID: taskID)

        #expect(firstRequest != secondRequest)
    }
}
