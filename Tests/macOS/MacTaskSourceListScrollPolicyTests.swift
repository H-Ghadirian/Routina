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

    @Test
    func locatedTaskScrollStagesEveryLazyAncestorBeforeTheRow() {
        let taskID = UUID()
        let request = MacSidebarTaskScrollRequest(
            taskID: taskID,
            destination: MacSidebarTaskScrollDestination(
                sectionID: "future:future",
                groupIDs: ["tag:travel", "tag:travel:routines"]
            )
        )

        #expect(
            MacTaskSourceListScrollPolicy.stagedScrollSteps(for: request) == [
                .section("future:future"),
                .group(sectionID: "future:future", groupID: "tag:travel"),
                .group(sectionID: "future:future", groupID: "tag:travel:routines"),
                .task(taskID)
            ]
        )
    }

    @Test
    func ordinaryScrollRequestTargetsTheRowDirectly() {
        let taskID = UUID()
        let request = MacSidebarTaskScrollRequest(taskID: taskID)

        #expect(
            MacTaskSourceListScrollPolicy.stagedScrollSteps(for: request) == [
                .task(taskID)
            ]
        )
    }
}

struct MacTaskSourceListScrollPreservationTests {
    @Test
    func userDrivenDisclosureChangesDoNotExposeAnimatedIntermediateOffsets() {
        #expect(!MacTaskSourceListScrollPreservation.animatesUserDrivenDisclosureChanges)
    }

    @Test
    func keepsExistingOriginWhenItFitsUpdatedContent() {
        #expect(
            MacTaskSourceListScrollPreservation.verticalOrigin(
                preserving: 240,
                documentHeight: 2_000,
                viewportHeight: 700
            ) == 240
        )
    }

    @Test
    func clampsExistingOriginAfterContentShrinks() {
        #expect(
            MacTaskSourceListScrollPreservation.verticalOrigin(
                preserving: 900,
                documentHeight: 1_200,
                viewportHeight: 700
            ) == 500
        )
    }
}

struct MacTaskSourceListKeyboardNavigationTests {
    @Test
    func downArrowMovesToNextVisibleTask() {
        let firstTaskID = UUID()
        let secondTaskID = UUID()
        let thirdTaskID = UUID()

        let target = MacTaskSourceListKeyboardNavigation.adjacentTaskID(
            from: firstTaskID,
            direction: .next,
            visibleTaskIDs: [firstTaskID, secondTaskID, thirdTaskID]
        )

        #expect(target == secondTaskID)
    }

    @Test
    func upArrowMovesToPreviousVisibleTask() {
        let firstTaskID = UUID()
        let secondTaskID = UUID()
        let thirdTaskID = UUID()

        let target = MacTaskSourceListKeyboardNavigation.adjacentTaskID(
            from: thirdTaskID,
            direction: .previous,
            visibleTaskIDs: [firstTaskID, secondTaskID, thirdTaskID]
        )

        #expect(target == secondTaskID)
    }

    @Test
    func arrowsDoNotWrapAtVisibleListEdges() {
        let firstTaskID = UUID()
        let secondTaskID = UUID()

        let previousFromFirst = MacTaskSourceListKeyboardNavigation.adjacentTaskID(
            from: firstTaskID,
            direction: .previous,
            visibleTaskIDs: [firstTaskID, secondTaskID]
        )
        let nextFromSecond = MacTaskSourceListKeyboardNavigation.adjacentTaskID(
            from: secondTaskID,
            direction: .next,
            visibleTaskIDs: [firstTaskID, secondTaskID]
        )

        #expect(previousFromFirst == nil)
        #expect(nextFromSecond == nil)
    }

    @Test
    func arrowsChooseEdgeTaskWhenSelectionIsMissingFromVisibleList() {
        let firstTaskID = UUID()
        let secondTaskID = UUID()
        let hiddenTaskID = UUID()

        let downTarget = MacTaskSourceListKeyboardNavigation.adjacentTaskID(
            from: hiddenTaskID,
            direction: .next,
            visibleTaskIDs: [firstTaskID, secondTaskID]
        )
        let upTarget = MacTaskSourceListKeyboardNavigation.adjacentTaskID(
            from: hiddenTaskID,
            direction: .previous,
            visibleTaskIDs: [firstTaskID, secondTaskID]
        )

        #expect(downTarget == firstTaskID)
        #expect(upTarget == secondTaskID)
    }
}
