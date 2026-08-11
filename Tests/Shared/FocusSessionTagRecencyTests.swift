import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct FocusSessionTagRecencyTests {
    @Test
    func ordersPreviouslyUsedTagsByMostRecentFocusStart() {
        let olderFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            tagName: "Chores"
        )
        let newerFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            tagName: "Bathroom"
        )

        #expect(
            FocusSessionTagRecency.orderedAvailableTags(
                ["Bathroom", "Bug", "Chores", "Cleaning"],
                focusSessions: [olderFocus, newerFocus]
            ) == ["Bathroom", "Chores", "Bug", "Cleaning"]
        )
    }

    @Test
    func ignoresFocusTagsThatAreNoLongerAvailable() {
        let removedTagFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 300),
            tagName: "Removed"
        )

        #expect(
            FocusSessionTagRecency.orderedAvailableTags(
                ["Bug", "Chores"],
                focusSessions: [removedTagFocus]
            ) == ["Bug", "Chores"]
        )
    }
}
