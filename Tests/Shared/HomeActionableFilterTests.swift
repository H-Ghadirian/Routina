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
struct HomeActionableFilterTests {
    @Test
    func activeBlockerHidesBlockedTask() {
        let blockedTaskID = UUID()
        let blockerID = UUID()
        let blockedTask = RoutineTask(
            id: blockedTaskID,
            name: "Submit report",
            relationships: [RoutineTaskRelationship(targetTaskID: blockerID, kind: .blockedBy)]
        )
        let blocker = RoutineTask(id: blockerID, name: "Draft report")

        #expect(HomeDisplayFilterSupport.hasActiveRelationshipBlocker(
            taskID: blockedTaskID,
            tasks: [blockedTask, blocker],
            referenceDate: Date(),
            calendar: .current
        ))
    }

    @Test
    func completedBlockerRevealsBlockedTask() {
        let blockedTaskID = UUID()
        let blockerID = UUID()
        let now = Date()
        let blockedTask = RoutineTask(
            id: blockedTaskID,
            name: "Submit report",
            relationships: [RoutineTaskRelationship(targetTaskID: blockerID, kind: .blockedBy)]
        )
        let blocker = RoutineTask(id: blockerID, name: "Draft report", lastDone: now)

        #expect(!HomeDisplayFilterSupport.hasActiveRelationshipBlocker(
            taskID: blockedTaskID,
            tasks: [blockedTask, blocker],
            referenceDate: now,
            calendar: .current
        ))
    }

    @Test
    func inverseBlocksRelationshipIsTreatedAsBlocker() {
        let blockedTaskID = UUID()
        let blocker = RoutineTask(
            name: "Draft report",
            relationships: [RoutineTaskRelationship(targetTaskID: blockedTaskID, kind: .blocks)]
        )
        let blockedTask = RoutineTask(id: blockedTaskID, name: "Submit report")

        #expect(HomeDisplayFilterSupport.hasActiveRelationshipBlocker(
            taskID: blockedTaskID,
            tasks: [blockedTask, blocker],
            referenceDate: Date(),
            calendar: .current
        ))
    }
}
