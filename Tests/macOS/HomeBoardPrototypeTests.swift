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
    func createBacklogConfirmed_addsNamedBacklogAndSelectsIt() async throws {
        let now = makeDate("2026-04-19T10:00:00Z")
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.date.now = now
        }
        store.exhaustivity = .off

        await store.send(.createBacklogTapped) {
            $0.creatingBacklogTitle = ""
        }

        await store.send(.createBacklogTitleChanged("Writing")) {
            $0.creatingBacklogTitle = "Writing"
        }

        await store.send(.createBacklogConfirmed)

        let backlog = try #require(store.state.sprintBoardData.backlogs.first)
        #expect(backlog.title == "Writing")
        #expect(store.state.selectedBoardScope == .namedBacklog(backlog.id))
    }

    @Test
    func assignTodoToBacklog_updatesBoardDisplayAssignment() async throws {
        let todo = RoutineTask(
            name: "Draft pitch",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        let backlog = BoardBacklog(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            title: "Writing",
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

        await store.send(.sprintBoardLoaded(SprintBoardData(backlogs: [backlog]))) {
            $0.sprintBoardData = SprintBoardData(backlogs: [backlog])
        }

        await store.send(.assignTodoToBacklog(taskID: todo.id, backlogID: backlog.id)) {
            $0.sprintBoardData.backlogAssignments = [BacklogAssignment(todoID: todo.id, backlogID: backlog.id)]
            $0.routineDisplays[0].assignedBacklogID = backlog.id
            $0.routineDisplays[0].assignedBacklogTitle = "Writing"
            $0.boardTodoDisplays[0].assignedBacklogID = backlog.id
            $0.boardTodoDisplays[0].assignedBacklogTitle = "Writing"
        }

        let display = try #require(store.state.boardTodoDisplays.first(where: { $0.id == todo.id }))
        #expect(display.assignedBacklogID == backlog.id)
        #expect(display.assignedBacklogTitle == "Writing")
        #expect(HomeFeature.matchesBoardScope(display, selectedScope: .namedBacklog(backlog.id), activeSprintIDs: []))
        #expect(!HomeFeature.matchesBoardScope(display, selectedScope: .backlog, activeSprintIDs: []))
    }

    @Test
    func assignTodoToSprint_clearsNamedBacklogAssignment() async throws {
        let todo = RoutineTask(
            name: "Draft pitch",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        let backlog = BoardBacklog(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            title: "Writing",
            createdAt: makeDate("2026-04-01T09:00:00Z")
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

        await store.send(
            .sprintBoardLoaded(
                SprintBoardData(
                    sprints: [sprint],
                    assignments: [],
                    backlogs: [backlog],
                    backlogAssignments: [BacklogAssignment(todoID: todo.id, backlogID: backlog.id)]
                )
            )
        ) {
            $0.sprintBoardData = SprintBoardData(
                sprints: [sprint],
                assignments: [],
                backlogs: [backlog],
                backlogAssignments: [BacklogAssignment(todoID: todo.id, backlogID: backlog.id)]
            )
            $0.routineDisplays[0].assignedBacklogID = backlog.id
            $0.routineDisplays[0].assignedBacklogTitle = "Writing"
            $0.boardTodoDisplays[0].assignedBacklogID = backlog.id
            $0.boardTodoDisplays[0].assignedBacklogTitle = "Writing"
        }

        await store.send(.assignTodoToSprint(taskID: todo.id, sprintID: sprint.id)) {
            $0.sprintBoardData.assignments = [SprintAssignment(todoID: todo.id, sprintID: sprint.id)]
            $0.sprintBoardData.backlogAssignments = []
            $0.routineDisplays[0].assignedSprintID = sprint.id
            $0.routineDisplays[0].assignedSprintTitle = "Sprint 7"
            $0.routineDisplays[0].assignedBacklogID = nil
            $0.routineDisplays[0].assignedBacklogTitle = nil
            $0.boardTodoDisplays[0].assignedSprintID = sprint.id
            $0.boardTodoDisplays[0].assignedSprintTitle = "Sprint 7"
            $0.boardTodoDisplays[0].assignedBacklogID = nil
            $0.boardTodoDisplays[0].assignedBacklogTitle = nil
        }

        #expect(store.state.sprintBoardData.backlogAssignments.isEmpty)
    }

    @Test
    func assignTodosToSprint_updatesBoardDisplayAssignments() async throws {
        let firstTodo = RoutineTask(
            name: "Plan next release",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        let secondTodo = RoutineTask(
            name: "Write test notes",
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
            .tasksLoadedSuccessfully([firstTodo, secondTodo], [], [], HomeFeature.DoneStats())
        )

        await store.send(.sprintBoardLoaded(SprintBoardData(sprints: [sprint], assignments: []))) {
            $0.sprintBoardData = SprintBoardData(sprints: [sprint], assignments: [])
        }

        await store.send(.assignTodosToSprint(taskIDs: [firstTodo.id, secondTodo.id], sprintID: sprint.id)) {
            $0.sprintBoardData.assignments = [
                SprintAssignment(todoID: firstTodo.id, sprintID: sprint.id),
                SprintAssignment(todoID: secondTodo.id, sprintID: sprint.id)
            ]
            $0.routineDisplays[0].assignedSprintID = sprint.id
            $0.routineDisplays[0].assignedSprintTitle = "Sprint 7"
            $0.routineDisplays[1].assignedSprintID = sprint.id
            $0.routineDisplays[1].assignedSprintTitle = "Sprint 7"
            $0.boardTodoDisplays[0].assignedSprintID = sprint.id
            $0.boardTodoDisplays[0].assignedSprintTitle = "Sprint 7"
            $0.boardTodoDisplays[1].assignedSprintID = sprint.id
            $0.boardTodoDisplays[1].assignedSprintTitle = "Sprint 7"
        }

        let assignedIDs = Set(
            store.state.boardTodoDisplays
                .filter { $0.assignedSprintID == sprint.id }
                .map(\.id)
        )
        #expect(assignedIDs == Set([firstTodo.id, secondTodo.id]))
    }

    @Test
    func startSprintTapped_allowsMultipleActiveSprints() async {
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
            $0.sprintBoardData.sprints[1].status = .active
            $0.sprintBoardData.sprints[1].startedAt = now
            $0.sprintBoardData.sprints[1].finishedAt = nil
            $0.selectedBoardScope = .currentSprint
        }

        #expect(Set(store.state.sprintBoardData.activeSprints.map(\.id)) == Set([previouslyActive.id, planned.id]))
        #expect(store.state.sprintBoardData.sprints[0].startedAt == previouslyActive.startedAt)
    }

    @Test
    func finishSprintTapped_keepsCurrentSprintScopeWhenOtherSprintsRemainActive() async {
        let now = makeDate("2026-04-19T10:00:00Z")
        let firstSprint = BoardSprint(
            id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
            title: "Sprint 1",
            status: .active,
            createdAt: makeDate("2026-04-01T09:00:00Z"),
            startedAt: makeDate("2026-04-10T09:00:00Z")
        )
        let secondSprint = BoardSprint(
            id: UUID(uuidString: "23232323-2323-2323-2323-232323232323")!,
            title: "Sprint 2",
            status: .active,
            createdAt: makeDate("2026-04-02T09:00:00Z"),
            startedAt: makeDate("2026-04-11T09:00:00Z")
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
                SprintBoardData(sprints: [firstSprint, secondSprint], assignments: [])
            )
        ) {
            $0.sprintBoardData = SprintBoardData(sprints: [firstSprint, secondSprint], assignments: [])
        }

        await store.send(.finishSprintTapped(firstSprint.id)) {
            $0.sprintBoardData.sprints[0].status = .finished
            $0.sprintBoardData.sprints[0].finishedAt = now
        }

        #expect(store.state.selectedBoardScope == .currentSprint)
        #expect(store.state.sprintBoardData.activeSprints.map(\.id) == [secondSprint.id])
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

    @Test
    func currentSprintScope_matchesTodosAssignedToAnyActiveSprint() async throws {
        let firstSprint = BoardSprint(
            id: UUID(uuidString: "56565656-5656-5656-5656-565656565656")!,
            title: "Active Sprint 1",
            status: .active,
            createdAt: makeDate("2026-04-16T09:00:00Z")
        )
        let secondSprint = BoardSprint(
            id: UUID(uuidString: "67676767-6767-6767-6767-676767676767")!,
            title: "Active Sprint 2",
            status: .active,
            createdAt: makeDate("2026-04-17T09:00:00Z")
        )
        let plannedSprint = BoardSprint(
            id: UUID(uuidString: "78787878-7878-7878-7878-787878787878")!,
            title: "Planned Sprint",
            status: .planned,
            createdAt: makeDate("2026-04-18T09:00:00Z")
        )
        let firstTodo = RoutineTask(name: "First active", scheduleMode: .oneOff, lastDone: nil)
        let secondTodo = RoutineTask(name: "Second active", scheduleMode: .oneOff, lastDone: nil)
        let plannedTodo = RoutineTask(name: "Planned", scheduleMode: .oneOff, lastDone: nil)
        let backlogTodo = RoutineTask(name: "Backlog", scheduleMode: .oneOff, lastDone: nil)

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(
            .tasksLoadedSuccessfully([firstTodo, secondTodo, plannedTodo, backlogTodo], [], [], HomeFeature.DoneStats())
        )

        var firstDisplay = try #require(store.state.boardTodoDisplays.first { $0.id == firstTodo.id })
        firstDisplay.assignedSprintID = firstSprint.id
        var secondDisplay = try #require(store.state.boardTodoDisplays.first { $0.id == secondTodo.id })
        secondDisplay.assignedSprintID = secondSprint.id
        var plannedDisplay = try #require(store.state.boardTodoDisplays.first { $0.id == plannedTodo.id })
        plannedDisplay.assignedSprintID = plannedSprint.id
        let backlogDisplay = try #require(store.state.boardTodoDisplays.first { $0.id == backlogTodo.id })

        let activeSprintIDs = Set([firstSprint.id, secondSprint.id])

        #expect(HomeFeature.matchesBoardScope(firstDisplay, selectedScope: .currentSprint, activeSprintIDs: activeSprintIDs))
        #expect(HomeFeature.matchesBoardScope(secondDisplay, selectedScope: .currentSprint, activeSprintIDs: activeSprintIDs))
        #expect(!HomeFeature.matchesBoardScope(plannedDisplay, selectedScope: .currentSprint, activeSprintIDs: activeSprintIDs))
        #expect(!HomeFeature.matchesBoardScope(backlogDisplay, selectedScope: .currentSprint, activeSprintIDs: activeSprintIDs))
    }

    @Test
    func backlogScope_excludesDoneTodos() async throws {
        let openTodo = RoutineTask(
            name: "Open backlog item",
            scheduleMode: .oneOff,
            lastDone: nil
        )
        let doneTodo = RoutineTask(
            name: "Done backlog item",
            scheduleMode: .oneOff,
            lastDone: makeDate("2026-04-20T09:00:00Z")
        )
        let sprint = BoardSprint(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            title: "Done Sprint",
            createdAt: makeDate("2026-04-18T09:00:00Z")
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }
        store.exhaustivity = .off

        await store.send(
            .tasksLoadedSuccessfully(
                [openTodo, doneTodo],
                [],
                [],
                HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [doneTodo.id: 1])
            )
        )

        let openDisplay = try #require(store.state.boardTodoDisplays.first { $0.id == openTodo.id })
        let doneDisplay = try #require(store.state.boardTodoDisplays.first { $0.id == doneTodo.id })

        #expect(HomeFeature.matchesBoardScope(openDisplay, selectedScope: .backlog, activeSprintIDs: []))
        #expect(!HomeFeature.matchesBoardScope(doneDisplay, selectedScope: .backlog, activeSprintIDs: []))

        var sprintDoneDisplay = doneDisplay
        sprintDoneDisplay.assignedSprintID = sprint.id
        #expect(HomeFeature.matchesBoardScope(sprintDoneDisplay, selectedScope: .sprint(sprint.id), activeSprintIDs: []))
    }
}
