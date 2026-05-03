import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct HomeBoardMutationSupportTests {
    @Test
    func createBacklogAndSprintTrimTitlesAndSelectCreatedScopes() {
        let now = makeDate("2026-04-12T09:00:00Z")
        var data = SprintBoardData()
        var scope = HomeBoardScope.backlog

        let didCreateBacklog = HomeBoardMutationSupport.createBacklog(
            title: "  Launch cleanup  ",
            now: now,
            data: &data,
            selectedScope: &scope
        )

        #expect(didCreateBacklog)
        #expect(data.backlogs.map(\.title) == ["Launch cleanup"])
        #expect(data.backlogs.first?.createdAt == now)
        #expect(scope == .namedBacklog(data.backlogs[0].id))

        let didCreateSprint = HomeBoardMutationSupport.createSprint(
            title: "  May focus  ",
            now: now,
            data: &data,
            selectedScope: &scope
        )

        #expect(didCreateSprint)
        #expect(data.sprints.map(\.title) == ["May focus"])
        #expect(scope == .namedBacklog(data.backlogs[0].id))
    }

    @Test
    func createSprintSelectsSprintWhenCurrentScopeIsGeneralBacklog() {
        var data = SprintBoardData()
        var scope = HomeBoardScope.backlog

        HomeBoardMutationSupport.createSprint(
            title: "Sprint 1",
            now: makeDate("2026-04-12T09:00:00Z"),
            data: &data,
            selectedScope: &scope
        )

        #expect(scope == .sprint(data.sprints[0].id))
    }

    @Test
    func assignTodosMovesTasksBetweenBacklogAndSprint() {
        let firstTodoID = UUID()
        let secondTodoID = UUID()
        let backlogID = UUID()
        let sprintID = UUID()
        var data = SprintBoardData(
            sprints: [BoardSprint(id: sprintID, title: "Sprint")],
            backlogs: [BoardBacklog(id: backlogID, title: "Inbox")]
        )

        HomeBoardMutationSupport.assignTodosToBacklog(
            taskIDs: [firstTodoID, secondTodoID, firstTodoID],
            backlogID: backlogID,
            data: &data
        )

        #expect(data.backlogAssignments == [
            BacklogAssignment(todoID: firstTodoID, backlogID: backlogID),
            BacklogAssignment(todoID: secondTodoID, backlogID: backlogID)
        ])

        HomeBoardMutationSupport.assignTodoToSprint(
            taskID: firstTodoID,
            sprintID: sprintID,
            data: &data
        )

        #expect(data.assignments == [
            SprintAssignment(todoID: firstTodoID, sprintID: sprintID)
        ])
        #expect(data.backlogAssignments == [
            BacklogAssignment(todoID: secondTodoID, backlogID: backlogID)
        ])

        HomeBoardMutationSupport.assignTodoToSprint(
            taskID: firstTodoID,
            sprintID: nil,
            data: &data
        )

        #expect(data.assignments.isEmpty)
        #expect(data.backlogAssignments == [
            BacklogAssignment(todoID: secondTodoID, backlogID: backlogID)
        ])
    }

    @Test
    func startFinishAndDeleteSprintUpdateStatusAndValidateScope() {
        let now = makeDate("2026-04-12T09:00:00Z")
        let later = makeDate("2026-04-20T09:00:00Z")
        let sprintID = UUID()
        var data = SprintBoardData(
            sprints: [BoardSprint(id: sprintID, title: "April")]
        )
        var scope = HomeBoardScope.sprint(sprintID)

        HomeBoardMutationSupport.startSprint(
            id: sprintID,
            now: now,
            data: &data,
            selectedScope: &scope
        )

        #expect(data.sprints[0].status == .active)
        #expect(data.sprints[0].startedAt == now)
        #expect(scope == .currentSprint)

        HomeBoardMutationSupport.finishSprint(
            id: sprintID,
            now: later,
            data: &data,
            selectedScope: &scope
        )

        #expect(data.sprints[0].status == .finished)
        #expect(data.sprints[0].finishedAt == later)
        #expect(scope == .backlog)

        scope = .sprint(sprintID)
        data.assignments = [SprintAssignment(todoID: UUID(), sprintID: sprintID)]
        HomeBoardMutationSupport.deleteSprint(
            id: sprintID,
            data: &data,
            selectedScope: &scope
        )

        #expect(data.sprints.isEmpty)
        #expect(data.assignments.isEmpty)
        #expect(scope == .backlog)
    }

    @Test
    func matchesScopeUsesSprintBacklogAndDoneRules() {
        let activeSprintID = UUID()
        let plannedSprintID = UUID()
        let backlogID = UUID()

        #expect(HomeBoardMutationSupport.matchesScope(
            assignedSprintID: nil,
            assignedBacklogID: nil,
            todoState: .ready,
            selectedScope: .backlog,
            activeSprintIDs: [activeSprintID]
        ))
        #expect(!HomeBoardMutationSupport.matchesScope(
            assignedSprintID: nil,
            assignedBacklogID: nil,
            todoState: .done,
            selectedScope: .backlog,
            activeSprintIDs: [activeSprintID]
        ))
        #expect(HomeBoardMutationSupport.matchesScope(
            assignedSprintID: nil,
            assignedBacklogID: backlogID,
            todoState: .ready,
            selectedScope: .namedBacklog(backlogID),
            activeSprintIDs: [activeSprintID]
        ))
        #expect(HomeBoardMutationSupport.matchesScope(
            assignedSprintID: activeSprintID,
            assignedBacklogID: nil,
            todoState: .ready,
            selectedScope: .currentSprint,
            activeSprintIDs: [activeSprintID]
        ))
        #expect(!HomeBoardMutationSupport.matchesScope(
            assignedSprintID: plannedSprintID,
            assignedBacklogID: nil,
            todoState: .ready,
            selectedScope: .currentSprint,
            activeSprintIDs: [activeSprintID]
        ))
    }
}
