import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskLadderOrganizationTests {
    private let referenceDate = Date(timeIntervalSince1970: 10_000)
    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func storageRoundTripsGroupsPlacementsAndScopedRanks() throws {
        let taskID = UUID()
        var company = TaskLadderGroup(
            name: " Company ",
            emoji: "🏢",
            pressure: .high,
            urgency: .level3,
            importance: .level4,
            thinkingNeeded: .medium,
            inheritedMetrics: [.pressure, .thinkingNeeded]
        )
        company.setTaskRankingOrder(
            42,
            for: .pressure,
            value: .pressure(.high)
        )
        let organization = TaskLadderOrganization(
            groups: [company],
            placements: [
                TaskLadderPlacement(taskID: taskID, parent: .group(company.id))
            ]
        )

        let rawValue = try #require(TaskLadderOrganizationStorage.encode(organization))
        let decoded = TaskLadderOrganizationStorage.decode(rawValue)

        #expect(decoded == organization)
        #expect(decoded.group(id: company.id)?.pressure == .high)
        #expect(decoded.group(id: company.id)?.inheritedMetrics == [.pressure, .thinkingNeeded])
        #expect(decoded.parent(of: taskID) == .group(company.id))
    }

    @Test
    func storageDecodesGroupsSavedBeforeInheritedValuesWereAdded() throws {
        let groupID = UUID()
        let rawValue = """
        {"groups":[{"createdAt":0,"emoji":"🏢","id":"\(groupID.uuidString)","name":"Company","pressureRawValue":"High","taskRankingOrders":{}}],"placements":[]}
        """

        let decoded = TaskLadderOrganizationStorage.decode(rawValue)
        let group = try #require(decoded.group(id: groupID))

        #expect(group.pressure == .high)
        #expect(group.inheritedMetrics.isEmpty)
    }

    @Test
    func explicitlyEnabledTaskGroupRoundTripsWithoutChildrenAndLegacyPayloadStillDecodes() throws {
        let taskID = UUID()
        var organization = TaskLadderOrganization()
        let enabled = organization.setTaskGroupEnabled(true, taskID: taskID)
        #expect(enabled)

        let rawValue = try #require(TaskLadderOrganizationStorage.encode(organization))
        let decoded = TaskLadderOrganizationStorage.decode(rawValue)
        let legacy = TaskLadderOrganizationStorage.decode("{\"groups\":[],\"placements\":[]}")

        #expect(decoded.isExplicitTaskGroup(taskID: taskID))
        #expect(decoded.isTaskGroup(taskID: taskID))
        #expect(decoded.childTaskIDs(of: .task(taskID)).isEmpty)
        #expect(legacy.taskGroupIDs == nil)
    }

    @Test
    func linkedTaskChildSuggestionRejectionsRoundTripAndSanitizeDeletedTasks() throws {
        let parentID = UUID()
        let linkedTaskID = UUID()
        let deletedLinkedTaskID = UUID()
        let organization = TaskLadderOrganization(
            taskGroupIDs: [parentID],
            rejectedLinkedTaskChildSuggestions: [
                TaskLadderLinkedTaskSuggestionRejection(
                    parentTaskID: parentID,
                    linkedTaskID: linkedTaskID
                ),
                TaskLadderLinkedTaskSuggestionRejection(
                    parentTaskID: parentID,
                    linkedTaskID: deletedLinkedTaskID
                )
            ]
        )

        let rawValue = try #require(TaskLadderOrganizationStorage.encode(organization))
        let decoded = TaskLadderOrganizationStorage.decode(rawValue)
        let sanitized = decoded.sanitized(validTaskIDs: [parentID, linkedTaskID])

        #expect(decoded.isLinkedTaskChildSuggestionRejected(
            parentTaskID: parentID,
            linkedTaskID: linkedTaskID
        ))
        #expect(sanitized.isLinkedTaskChildSuggestionRejected(
            parentTaskID: parentID,
            linkedTaskID: linkedTaskID
        ))
        #expect(!sanitized.isLinkedTaskChildSuggestionRejected(
            parentTaskID: parentID,
            linkedTaskID: deletedLinkedTaskID
        ))
    }

    @Test
    func placingARejectedLinkedTaskInsideItsParentAcceptsTheSuggestion() {
        let parentID = UUID()
        let linkedTaskID = UUID()
        var organization = TaskLadderOrganization(
            taskGroupIDs: [parentID],
            rejectedLinkedTaskChildSuggestions: [
                TaskLadderLinkedTaskSuggestionRejection(
                    parentTaskID: parentID,
                    linkedTaskID: linkedTaskID
                )
            ]
        )

        let placed = organization.place(
            taskID: linkedTaskID,
            inside: .task(parentID),
            validTaskIDs: [parentID, linkedTaskID]
        )

        #expect(placed)
        #expect(organization.parent(of: linkedTaskID) == .task(parentID))
        #expect(!organization.isLinkedTaskChildSuggestionRejected(
            parentTaskID: parentID,
            linkedTaskID: linkedTaskID
        ))
    }

    @Test
    func disablingTaskGroupPreservesAnInUseGroupUntilChildrenAreMoved() {
        let parentID = UUID()
        let childID = UUID()
        var organization = TaskLadderOrganization(
            placements: [TaskLadderPlacement(taskID: childID, parent: .task(parentID))],
            taskGroupIDs: [parentID]
        )

        let disabledWhileInUse = organization.setTaskGroupEnabled(false, taskID: parentID)
        #expect(!disabledWhileInUse)
        #expect(organization.isTaskGroup(taskID: parentID))

        let movedToRoot = organization.place(
            taskID: childID,
            inside: nil,
            validTaskIDs: [parentID, childID]
        )
        let disabledAfterMove = organization.setTaskGroupEnabled(false, taskID: parentID)
        #expect(movedToRoot)
        #expect(disabledAfterMove)
        #expect(!organization.isTaskGroup(taskID: parentID))
    }

    @Test
    func sanitizingOrganizationRemovesTaskGroupIDsForDeletedTasks() {
        let retainedID = UUID()
        let deletedID = UUID()
        let organization = TaskLadderOrganization(taskGroupIDs: [retainedID, deletedID])

        let sanitized = organization.sanitized(validTaskIDs: [retainedID])

        #expect(sanitized.isTaskGroup(taskID: retainedID))
        #expect(!sanitized.isTaskGroup(taskID: deletedID))
    }

    @Test
    func placementRejectsCyclesWithoutDiscardingTheExistingParent() {
        let exerciseID = UUID()
        let walkID = UUID()
        let validTaskIDs: Set<UUID> = [exerciseID, walkID]
        var organization = TaskLadderOrganization()

        let placedWalk = organization.place(
            taskID: walkID,
            inside: .task(exerciseID),
            validTaskIDs: validTaskIDs
        )
        let placedExercise = organization.place(
            taskID: exerciseID,
            inside: .task(walkID),
            validTaskIDs: validTaskIDs
        )

        #expect(placedWalk)
        #expect(!placedExercise)
        #expect(organization.parent(of: walkID) == .task(exerciseID))
        #expect(organization.parent(of: exerciseID) == nil)
    }

    @Test
    func deletingGroupReturnsItsTasksToTheRootWithoutDeletingTaskData() {
        let ticketID = UUID()
        let company = TaskLadderGroup(name: "Company", emoji: "🏢")
        var organization = TaskLadderOrganization(
            groups: [company],
            placements: [
                TaskLadderPlacement(taskID: ticketID, parent: .group(company.id))
            ]
        )

        organization.deleteGroup(id: company.id)

        #expect(organization.groups.isEmpty)
        #expect(organization.parent(of: ticketID) == nil)
    }

    @Test
    func containerGroupsAndCompletableParentsUseTheSameIndependentPlacement() throws {
        let company = TaskLadderGroup(
            name: "Company",
            emoji: "🏢",
            pressure: .high
        )
        let ticket = RoutineTask(name: "Fix Amplitude", pressure: .medium)
        let exercise = RoutineTask(name: "Exercise", pressure: .low)
        let walk = RoutineTask(
            name: "Walk",
            pressure: .medium,
            relationships: [
                RoutineTaskRelationship(targetTaskID: exercise.id, kind: .canComplete)
            ]
        )
        let organization = TaskLadderOrganization(
            groups: [company],
            placements: [
                TaskLadderPlacement(taskID: ticket.id, parent: .group(company.id)),
                TaskLadderPlacement(taskID: walk.id, parent: .task(exercise.id))
            ]
        )
        let tasks = [ticket, exercise, walk]

        let root = TaskRankingPresentation.make(
            tasks: tasks,
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let rootIDs = Set(root.sections.flatMap(\.tasks).map(\.id))
        #expect(rootIDs == Set([company.id, exercise.id]))
        #expect(root.rowMetadataByTaskID[company.id]?.isGroup == true)
        #expect(root.rowMetadataByTaskID[company.id]?.childCount == 1)
        #expect(root.rowMetadataByTaskID[exercise.id]?.isGroup == false)
        #expect(root.rowMetadataByTaskID[exercise.id]?.childCount == 1)

        let companyLadder = TaskRankingPresentation.make(
            tasks: tasks,
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            scopePath: [company.id]
        )
        #expect(companyLadder.sections.flatMap(\.tasks).map(\.id) == [ticket.id])

        let exerciseLadder = TaskRankingPresentation.make(
            tasks: tasks,
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            scopePath: [exercise.id]
        )
        #expect(exerciseLadder.sections.flatMap(\.tasks).map(\.id) == [walk.id])
        #expect(walk.relationships.first?.kind == .canComplete)
        #expect(ticket.relationships.isEmpty)
    }

    @Test
    func completionRelationshipAloneDoesNotChangePlacement() {
        let exercise = RoutineTask(name: "Exercise", pressure: .low)
        let cycle = RoutineTask(
            name: "Cycle",
            pressure: .medium,
            relationships: [
                RoutineTaskRelationship(targetTaskID: exercise.id, kind: .canComplete)
            ]
        )

        let presentation = TaskRankingPresentation.make(
            tasks: [exercise, cycle],
            organization: TaskLadderOrganization(),
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(Set(presentation.sections.flatMap(\.tasks).map(\.id)) == Set([exercise.id, cycle.id]))
        #expect(presentation.rowMetadataByTaskID[exercise.id]?.childCount == 0)
    }

    @Test
    func groupAndTaskRanksCanBeUpdatedInTheSameRootBucket() throws {
        var company = TaskLadderGroup(name: "Company", pressure: .high)
        company.setTaskRankingOrder(1_000_000, for: .pressure, value: .pressure(.high))
        let callMom = RoutineTask(name: "Call Mom", pressure: .high)
        callMom.setTaskRankingOrder(0, for: .pressure, value: .pressure(.high))
        var tasks = [callMom]
        var organization = TaskLadderOrganization(groups: [company])

        let presentation = TaskRankingPresentation.make(
            tasks: tasks,
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(presentation.sections.first?.tasks.map(\.id) == [callMom.id, company.id])

        let update = try #require(
            TaskRankingOrderingSupport.moveTask(
                taskID: company.id,
                direction: .up,
                in: presentation
            )
        )
        TaskRankingOrderingSupport.apply(
            update,
            to: &tasks,
            organization: &organization
        )

        let movedCompany = try #require(organization.group(id: company.id))
        #expect(update.nodeID == .group(company.id))
        #expect(movedCompany.taskRankingOrder(
            for: .pressure,
            value: .pressure(.high)
        ) != 1_000_000)
        #expect(callMom.taskRankingOrder(for: .pressure, value: .pressure(.high)) == 0)
    }

    @Test
    func movingInheritedGroupWithinItsValuePreservesInheritance() throws {
        var company = TaskLadderGroup(
            name: "Company",
            inheritedMetrics: [.pressure]
        )
        company.setTaskRankingOrder(1_000_000, for: .pressure, value: .pressure(.high))
        let ticket = RoutineTask(name: "Ticket", pressure: .high)
        let callMom = RoutineTask(name: "Call Mom", pressure: .high)
        callMom.setTaskRankingOrder(0, for: .pressure, value: .pressure(.high))
        var tasks = [ticket, callMom]
        var organization = TaskLadderOrganization(
            groups: [company],
            placements: [
                TaskLadderPlacement(taskID: ticket.id, parent: .group(company.id))
            ]
        )
        let presentation = TaskRankingPresentation.make(
            tasks: tasks,
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let update = try #require(
            TaskRankingOrderingSupport.moveTask(
                taskID: company.id,
                direction: .up,
                in: presentation
            )
        )
        TaskRankingOrderingSupport.apply(
            update,
            to: &tasks,
            organization: &organization
        )

        #expect(!update.changesMetricValue)
        #expect(organization.group(id: company.id)?.inheritsValue(for: .pressure) == true)
    }

    @Test
    func movingInheritedGroupAcrossValuesMakesTheDestinationExplicit() throws {
        let company = TaskLadderGroup(
            name: "Company",
            inheritedMetrics: [.pressure]
        )
        let ticket = RoutineTask(name: "Ticket", pressure: .medium)
        let callMom = RoutineTask(name: "Call Mom", pressure: .high)
        var tasks = [ticket, callMom]
        var organization = TaskLadderOrganization(
            groups: [company],
            placements: [
                TaskLadderPlacement(taskID: ticket.id, parent: .group(company.id))
            ]
        )
        let presentation = TaskRankingPresentation.make(
            tasks: tasks,
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let update = try #require(
            TaskRankingOrderingSupport.moveTask(
                taskID: company.id,
                direction: .up,
                in: presentation
            )
        )
        TaskRankingOrderingSupport.apply(
            update,
            to: &tasks,
            organization: &organization
        )
        let movedGroup = try #require(organization.group(id: company.id))

        #expect(update.changesMetricValue)
        #expect(!movedGroup.inheritsValue(for: .pressure))
        #expect(movedGroup.pressure == .high)
    }

    @Test @MainActor
    func completionBehaviorMutationSupportsNoneManualAndAutomatic() throws {
        let container = try PersistenceController.makeLocalOnlyContainer(inMemory: true)
        let context = ModelContext(container)
        let exercise = RoutineTask(name: "Exercise")
        let walk = RoutineTask(name: "Walk")
        context.insert(exercise)
        context.insert(walk)
        try context.save()

        _ = try RoutineTaskRelationshipMutationSupport.setCompletionBehavior(
            sourceTaskID: walk.id,
            targetTaskID: exercise.id,
            behavior: .canComplete,
            timestamp: referenceDate,
            calendar: calendar,
            context: context
        )
        #expect(walk.relationships.first?.kind == .canComplete)

        _ = try RoutineTaskRelationshipMutationSupport.setCompletionBehavior(
            sourceTaskID: walk.id,
            targetTaskID: exercise.id,
            behavior: .completes,
            timestamp: referenceDate,
            calendar: calendar,
            context: context
        )
        #expect(walk.relationships.first?.kind == .completes)

        _ = try RoutineTaskRelationshipMutationSupport.setCompletionBehavior(
            sourceTaskID: walk.id,
            targetTaskID: exercise.id,
            behavior: .none,
            timestamp: referenceDate,
            calendar: calendar,
            context: context
        )
        #expect(walk.relationships.isEmpty)
    }
}
