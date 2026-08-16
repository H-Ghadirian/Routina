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
    func pausedRepeatingBlockerStaysResolvedUntilDependentCompletes() {
        let blockedTaskID = UUID()
        let blockerID = UUID()
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSince1970: 500)
        let blockedTask = RoutineTask(
            id: blockedTaskID,
            name: "Release Candidate 4.4.0",
            relationships: [RoutineTaskRelationship(targetTaskID: blockerID, kind: .blockedBy)],
            lastDone: Date(timeIntervalSince1970: 100)
        )
        let blocker = RoutineTask(
            id: blockerID,
            name: "Run Test.io",
            lastDone: Date(timeIntervalSince1970: 200),
            pausedAt: Date(timeIntervalSince1970: 300)
        )

        #expect(!HomeDisplayFilterSupport.hasActiveRelationshipBlocker(
            taskID: blockedTaskID,
            tasks: [blockedTask, blocker],
            referenceDate: referenceDate,
            calendar: calendar
        ))

        blockedTask.lastDone = Date(timeIntervalSince1970: 400)

        #expect(HomeDisplayFilterSupport.hasActiveRelationshipBlocker(
            taskID: blockedTaskID,
            tasks: [blockedTask, blocker],
            referenceDate: referenceDate,
            calendar: calendar
        ))
    }

    @Test
    func recordedBlockerCompletionUnlocksChainWhenTaskSummaryLags() {
        let blockedTaskID = UUID()
        let blockerID = UUID()
        let blockedTask = RoutineTask(
            id: blockedTaskID,
            name: "Release Candidate 4.4.0",
            relationships: [RoutineTaskRelationship(targetTaskID: blockerID, kind: .blockedBy)],
            lastDone: Date(timeIntervalSince1970: 100)
        )
        let blocker = RoutineTask(id: blockerID, name: "Run Test.io")

        #expect(!HomeDisplayFilterSupport.hasActiveRelationshipBlocker(
            taskID: blockedTaskID,
            tasks: [blockedTask, blocker],
            referenceDate: Date(timeIntervalSince1970: 500),
            calendar: Calendar(identifier: .gregorian),
            completionDatesByTaskID: [blockerID: [Date(timeIntervalSince1970: 200)]]
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
