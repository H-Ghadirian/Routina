import ComposableArchitecture
import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct HomeBoardPrototypeTests {
    @Test
    func tasksLoadedSuccessfully_populatesBoardTodosIncludingDoneOnes() async {
        let activeTodo = RoutineTask(
            name: "Plan sprint",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        let doneTodo = RoutineTask(
            name: "Ship release",
            scheduleMode: .oneOff,
            lastDone: makeDate("2026-03-21T09:00:00Z")
        )
        let routine = RoutineTask(
            name: "Drink water",
            scheduleMode: .fixedInterval,
            interval: 1
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(
            .tasksLoadedSuccessfully(
                [activeTodo, doneTodo, routine],
                [],
                [],
                HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [doneTodo.id: 1])
            )
        )

        #expect(store.state.boardTodoDisplays.count == 2)
        #expect(store.state.boardTodoDisplays.contains(where: { $0.id == activeTodo.id }))
        #expect(store.state.boardTodoDisplays.contains(where: { $0.id == doneTodo.id && $0.todoState == .done }))
        #expect(!store.state.routineDisplays.contains(where: { $0.id == doneTodo.id }))
    }

    @Test
    func moveTodoToState_fromPausedToInProgress_clearsPause() async throws {
        let context = makeInMemoryContext()
        let pausedTodo = makeTask(
            in: context,
            name: "Write notes",
            interval: 1,
            lastDone: nil,
            emoji: "📝",
            scheduleMode: .oneOff,
            pausedAt: makeDate("2026-03-19T09:00:00Z")
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { @MainActor in context }
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(
            .tasksLoadedSuccessfully([pausedTodo], [], [], HomeFeature.DoneStats())
        )
        await store.send(.moveTodoToState(pausedTodo.id, .inProgress))

        let updatedTask = try #require(store.state.routineTasks.first(where: { $0.id == pausedTodo.id }))
        #expect(updatedTask.pausedAt == nil)
        #expect(updatedTask.todoStateRawValue == TodoState.inProgress.rawValue)

        let boardDisplay = try #require(store.state.boardTodoDisplays.first(where: { $0.id == pausedTodo.id }))
        #expect(boardDisplay.todoState == .inProgress)
    }

    @Test
    func macSidebarModeChanged_boardForcesTodoMode() async {
        let todo = RoutineTask(
            name: "Review PR",
            scheduleMode: .oneOff,
            lastDone: nil
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [todo],
                selectedTaskID: todo.id,
                taskListMode: .all
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(.macSidebarModeChanged(.board)) {
            $0.macSidebarMode = .board
            $0.macSidebarSelection = .task(todo.id)
        }
        await store.receive(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
        }
    }

    @Test
    func moveTodoOnBoard_reordersWithinSameColumn() async {
        let context = makeInMemoryContext()
        let first = RoutineTask(
            name: "First",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        first.todoStateRawValue = TodoState.ready.rawValue
        first.setManualSectionOrder(0, for: HomeFeature.boardSectionKey(for: .ready))

        let second = RoutineTask(
            name: "Second",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        second.todoStateRawValue = TodoState.ready.rawValue
        second.setManualSectionOrder(1, for: HomeFeature.boardSectionKey(for: .ready))

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { @MainActor in context }
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(
            .tasksLoadedSuccessfully([first, second], [], [], HomeFeature.DoneStats())
        )

        await store.send(
            .moveTodoOnBoard(
                taskID: second.id,
                targetState: .ready,
                orderedTaskIDs: [second.id, first.id]
            )
        ) {
            let firstIndex = $0.routineTasks.firstIndex(where: { $0.id == first.id })!
            let secondIndex = $0.routineTasks.firstIndex(where: { $0.id == second.id })!
            $0.routineTasks[firstIndex].setManualSectionOrder(1, for: HomeFeature.boardSectionKey(for: .ready))
            $0.routineTasks[secondIndex].setManualSectionOrder(0, for: HomeFeature.boardSectionKey(for: .ready))
        }

        let readyTasks = store.state.boardTodoDisplays
            .filter { $0.todoState == .ready }
            .sorted {
                ($0.manualSectionOrders[HomeFeature.boardSectionKey(for: .ready)] ?? .max)
                < ($1.manualSectionOrders[HomeFeature.boardSectionKey(for: .ready)] ?? .max)
            }

        #expect(readyTasks.map(\.id) == [second.id, first.id])
    }

    @Test
    func moveTodoOnBoard_movesAcrossColumnsAndAppliesDestinationOrder() async {
        let context = makeInMemoryContext()
        let firstBlocked = RoutineTask(
            name: "Blocked A",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        firstBlocked.todoStateRawValue = TodoState.blocked.rawValue
        firstBlocked.setManualSectionOrder(0, for: HomeFeature.boardSectionKey(for: .blocked))

        let moving = RoutineTask(
            name: "Ready Task",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        moving.todoStateRawValue = TodoState.ready.rawValue
        moving.setManualSectionOrder(0, for: HomeFeature.boardSectionKey(for: .ready))

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { @MainActor in context }
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(
            .tasksLoadedSuccessfully([firstBlocked, moving], [], [], HomeFeature.DoneStats())
        )

        await store.send(
            .moveTodoOnBoard(
                taskID: moving.id,
                targetState: .blocked,
                orderedTaskIDs: [moving.id, firstBlocked.id]
            )
        ) {
            let movingIndex = $0.routineTasks.firstIndex(where: { $0.id == moving.id })!
            $0.routineTasks[movingIndex].pausedAt = nil
            $0.routineTasks[movingIndex].snoozedUntil = nil
            $0.routineTasks[movingIndex].todoStateRawValue = TodoState.blocked.rawValue
            $0.routineTasks[movingIndex].setManualSectionOrder(1, for: HomeFeature.boardSectionKey(for: .blocked))
        }

        await store.receive(
            .setTaskOrderInSection(
                sectionKey: HomeFeature.boardSectionKey(for: .blocked),
                orderedTaskIDs: [moving.id, firstBlocked.id]
            )
        ) {
            let firstBlockedIndex = $0.routineTasks.firstIndex(where: { $0.id == firstBlocked.id })!
            let movingIndex = $0.routineTasks.firstIndex(where: { $0.id == moving.id })!
            $0.routineTasks[movingIndex].setManualSectionOrder(0, for: HomeFeature.boardSectionKey(for: .blocked))
            $0.routineTasks[firstBlockedIndex].setManualSectionOrder(1, for: HomeFeature.boardSectionKey(for: .blocked))
        }

        let blockedTasks = store.state.boardTodoDisplays
            .filter { $0.todoState == .blocked }
            .sorted {
                ($0.manualSectionOrders[HomeFeature.boardSectionKey(for: .blocked)] ?? .max)
                < ($1.manualSectionOrders[HomeFeature.boardSectionKey(for: .blocked)] ?? .max)
            }

        #expect(blockedTasks.map(\.id) == [moving.id, firstBlocked.id])
    }

    @Test
    func assignTodoToSprint_updatesBoardDisplayAssignment() async throws {
        let todo = RoutineTask(
            name: "Plan next release",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        let sprint = BoardSprint(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            title: "Sprint 7",
            createdAt: makeDate("2026-04-01T09:00:00Z")
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(
            .tasksLoadedSuccessfully([todo], [], [], HomeFeature.DoneStats())
        )

        await store.send(.sprintBoardLoaded(SprintBoardData(sprints: [sprint], assignments: []))) {
            $0.sprintBoardData = SprintBoardData(sprints: [sprint], assignments: [])
        }

        await store.send(.assignTodoToSprint(taskID: todo.id, sprintID: sprint.id)) {
            $0.sprintBoardData.assignments = [SprintAssignment(todoID: todo.id, sprintID: sprint.id)]
            $0.routineDisplays[0].assignedSprintID = sprint.id
            $0.routineDisplays[0].assignedSprintTitle = "Sprint 7"
            $0.boardTodoDisplays[0].assignedSprintID = sprint.id
            $0.boardTodoDisplays[0].assignedSprintTitle = "Sprint 7"
        }

        let display = try #require(store.state.boardTodoDisplays.first(where: { $0.id == todo.id }))
        #expect(display.assignedSprintID == sprint.id)
        #expect(display.assignedSprintTitle == "Sprint 7")
    }

    @Test
    func startSprintTapped_makesOnlySelectedSprintActive() async {
        let now = makeDate("2026-04-19T10:00:00Z")
        let previouslyActive = BoardSprint(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Sprint 1",
            status: .active,
            createdAt: makeDate("2026-04-01T09:00:00Z"),
            startedAt: makeDate("2026-04-10T09:00:00Z")
        )
        let planned = BoardSprint(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Sprint 2",
            status: .planned,
            createdAt: makeDate("2026-04-15T09:00:00Z")
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.date.now = now
        }
        store.exhaustivity = .off

        await store.send(
            .sprintBoardLoaded(
                SprintBoardData(sprints: [previouslyActive, planned], assignments: [])
            )
        ) {
            $0.sprintBoardData = SprintBoardData(sprints: [previouslyActive, planned], assignments: [])
        }

        await store.send(.startSprintTapped(planned.id)) {
            $0.sprintBoardData.sprints[0].status = .planned
            $0.sprintBoardData.sprints[0].startedAt = nil
            $0.sprintBoardData.sprints[1].status = .active
            $0.sprintBoardData.sprints[1].startedAt = now
            $0.sprintBoardData.sprints[1].finishedAt = nil
            $0.selectedBoardScope = .currentSprint
        }

        #expect(store.state.sprintBoardData.activeSprint?.id == planned.id)
        #expect(store.state.sprintBoardData.sprints.filter { $0.status == .active }.count == 1)
    }

    @Test
    func finishSprintTapped_marksSprintFinishedAndReturnsBoardToBacklog() async {
        let now = makeDate("2026-04-19T10:00:00Z")
        let activeSprint = BoardSprint(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "Sprint 3",
            status: .active,
            createdAt: makeDate("2026-04-01T09:00:00Z"),
            startedAt: makeDate("2026-04-12T09:00:00Z")
        )

        let store = TestStore(
            initialState: HomeFeature.State(selectedBoardScope: .currentSprint)
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.date.now = now
        }
        store.exhaustivity = .off

        await store.send(
            .sprintBoardLoaded(
                SprintBoardData(sprints: [activeSprint], assignments: [])
            )
        ) {
            $0.sprintBoardData = SprintBoardData(sprints: [activeSprint], assignments: [])
        }

        await store.send(.finishSprintTapped(activeSprint.id)) {
            $0.sprintBoardData.sprints[0].status = .finished
            $0.sprintBoardData.sprints[0].finishedAt = now
            $0.selectedBoardScope = .backlog
        }

        #expect(store.state.sprintBoardData.sprints[0].status == .finished)
        #expect(store.state.selectedBoardScope == .backlog)
    }

    @Test
    func boardSprintActiveDayCount_countsInclusiveCalendarDays() {
        let sprint = BoardSprint(
            title: "Release Sprint",
            status: .active,
            createdAt: makeDate("2026-04-01T09:00:00Z"),
            startedAt: makeDate("2026-04-17T16:00:00Z")
        )
        let calendar = Calendar(identifier: .gregorian)

        let activeDays = sprint.activeDayCount(
            relativeTo: makeDate("2026-04-19T08:00:00Z"),
            calendar: calendar
        )

        #expect(activeDays == 3)
    }

    @Test
    func currentSprintScope_withoutActiveSprintDoesNotShowBacklogItems() async {
        let backlogTodo = RoutineTask(
            name: "Backlog item",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        let sprintTodo = RoutineTask(
            name: "Sprint item",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        let plannedSprint = BoardSprint(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "Planned Sprint",
            status: .planned,
            createdAt: makeDate("2026-04-18T09:00:00Z")
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(
            .tasksLoadedSuccessfully([backlogTodo, sprintTodo], [], [], HomeFeature.DoneStats())
        )

        await store.send(
            .sprintBoardLoaded(
                SprintBoardData(
                    sprints: [plannedSprint],
                    assignments: [SprintAssignment(todoID: sprintTodo.id, sprintID: plannedSprint.id)]
                )
            )
        ) {
            $0.sprintBoardData = SprintBoardData(
                sprints: [plannedSprint],
                assignments: [SprintAssignment(todoID: sprintTodo.id, sprintID: plannedSprint.id)]
            )
            $0.routineDisplays[1].assignedSprintID = plannedSprint.id
            $0.routineDisplays[1].assignedSprintTitle = "Planned Sprint"
            $0.boardTodoDisplays[1].assignedSprintID = plannedSprint.id
            $0.boardTodoDisplays[1].assignedSprintTitle = "Planned Sprint"
        }

        await store.send(.selectedBoardScopeChanged(.currentSprint)) {
            $0.selectedBoardScope = .currentSprint
        }

        #expect(store.state.selectedBoardScope == .currentSprint)
        #expect(store.state.boardTodoDisplays.contains(where: { $0.id == backlogTodo.id && $0.assignedSprintID == nil }))
        #expect(store.state.boardTodoDisplays.contains(where: { $0.id == sprintTodo.id && $0.assignedSprintID == plannedSprint.id }))
    }
}
