import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct HomeFeatureTaskListModeTests {
    @Test
    func taskListMode_defaultsToTodos() {
        let state = HomeFeature.State()
        #expect(state.taskListMode == .todos)
    }

    @Test
    func taskListModeChanged_updatesMode() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
        }

        await store.send(.taskListModeChanged(.all)) {
            $0.taskListMode = .all
        }

        await store.send(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
        }
    }

    @Test
    func taskListModeChanged_toTodos_clearsRoutineSelection() async {
        let context = makeInMemoryContext()
        let routine = makeTask(in: context, name: "Meditate", interval: 1, lastDone: nil, emoji: "🧘")
        let routineID = routine.id

        let initialState = HomeFeature.State(
            routineTasks: [routine],
            routineDisplays: [makeDisplay(taskID: routineID, name: "Meditate", emoji: "🧘",
                                          interval: 1, lastDone: nil, isOneOffTask: false,
                                          isDoneToday: false)],
            selectedTaskID: routineID
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
            $0.selectedTaskID = nil
            $0.taskDetailState = nil
        }
    }

    @Test
    func taskListModeChanged_toRoutines_clearsTodoSelection() async {
        let context = makeInMemoryContext()
        let todo = makeTask(in: context, name: "Buy milk", interval: 1, lastDone: nil, emoji: "🛒",
                            scheduleMode: .oneOff)
        let todoID = todo.id

        let initialState = HomeFeature.State(
            routineTasks: [todo],
            routineDisplays: [makeDisplay(taskID: todoID, name: "Buy milk", emoji: "🛒",
                                          interval: 1, scheduleMode: .oneOff, lastDone: nil,
                                          isOneOffTask: true, isDoneToday: false)],
            selectedTaskID: todoID,
            taskListMode: .todos
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            $0.selectedTaskID = nil
            $0.taskDetailState = nil
        }
    }

    @Test
    func taskListModeChanged_toTodos_keepsTodoSelection() async {
        let context = makeInMemoryContext()
        let todo = makeTask(in: context, name: "Buy milk", interval: 1, lastDone: nil, emoji: "🛒",
                            scheduleMode: .oneOff)
        let todoID = todo.id

        let initialState = HomeFeature.State(
            routineTasks: [todo],
            routineDisplays: [makeDisplay(taskID: todoID, name: "Buy milk", emoji: "🛒",
                                          interval: 1, scheduleMode: .oneOff, lastDone: nil,
                                          isOneOffTask: true, isDoneToday: false)],
            selectedTaskID: todoID,
            taskListMode: .routines
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
            // selectedTaskID unchanged — todo stays selected
        }
        #expect(store.state.selectedTaskID == todoID)
    }

    @Test
    func taskListModeChanged_toRoutines_keepsRoutineSelection() async {
        let context = makeInMemoryContext()
        let routine = makeTask(in: context, name: "Meditate", interval: 1, lastDone: nil, emoji: "🧘")
        let routineID = routine.id

        let initialState = HomeFeature.State(
            routineTasks: [routine],
            routineDisplays: [makeDisplay(taskID: routineID, name: "Meditate", emoji: "🧘",
                                          interval: 1, lastDone: nil, isOneOffTask: false,
                                          isDoneToday: false)],
            selectedTaskID: routineID,
            taskListMode: .todos
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            // selectedTaskID unchanged — routine stays selected
        }
        #expect(store.state.selectedTaskID == routineID)
    }

    @Test
    func taskListModeChanged_withNoSelection_onlyUpdatesMode() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            // no selection to clear — everything else stays the same
        }
    }

    @Test
    func taskListModeChanged_toAll_keepsCurrentSelection() async {
        let context = makeInMemoryContext()
        let todo = makeTask(
            in: context,
            name: "Buy milk",
            interval: 1,
            lastDone: nil,
            emoji: "🛒",
            scheduleMode: .oneOff
        )
        let todoID = todo.id

        let initialState = HomeFeature.State(
            routineTasks: [todo],
            routineDisplays: [
                makeDisplay(
                    taskID: todoID,
                    name: "Buy milk",
                    emoji: "🛒",
                    interval: 1,
                    scheduleMode: .oneOff,
                    lastDone: nil,
                    isOneOffTask: true,
                    isDoneToday: false
                )
            ],
            selectedTaskID: todoID,
            taskListMode: .todos
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.all)) {
            $0.taskListMode = .all
        }

        #expect(store.state.selectedTaskID == todoID)
    }

    @Test
    func taskListModeChanged_toAll_restoresSavedSnapshot() async {
        let context = makeInMemoryContext()
        let todoPlaceID = UUID()
        let allPlaceID = UUID()

        let initialState = HomeFeature.State(
            taskListMode: .todos,
            selectedFilter: .due,
            selectedTag: "Errands",
            excludedTags: ["Home"],
            selectedManualPlaceFilterID: todoPlaceID,
            tabFilterSnapshots: [
                HomeFeature.TaskListMode.all.rawValue: TabFilterStateManager.Snapshot(
                    selectedTag: "Focus",
                    excludedTags: ["Work"],
                    selectedFilter: .doneToday,
                    selectedManualPlaceFilterID: allPlaceID
                )
            ]
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.all)) {
            $0.taskListMode = .all
            $0.selectedFilter = .doneToday
            $0.selectedTag = "Focus"
            $0.excludedTags = ["Work"]
            $0.selectedManualPlaceFilterID = allPlaceID
            $0.tabFilterSnapshots[HomeFeature.TaskListMode.todos.rawValue] = TabFilterStateManager.Snapshot(
                selectedTag: "Errands",
                excludedTags: ["Home"],
                selectedFilter: .due,
                selectedManualPlaceFilterID: todoPlaceID
            )
        }
    }

    @Test
    func macSidebarSelectionChanged_selectingTodoFromAllKeepsAllMode() async {
        let context = makeInMemoryContext()
        let todo = makeTask(
            in: context,
            name: "Buy milk",
            interval: 1,
            lastDone: nil,
            emoji: "🛒",
            scheduleMode: .oneOff
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [todo],
                taskListMode: .all,
                macSidebarMode: .routines
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.macSidebarSelectionChanged(.task(todo.id))) {
            $0.macSidebarSelection = .task(todo.id)
        }
        await store.receive(.setSelectedTask(todo.id))

        #expect(store.state.taskListMode == .all)
        #expect(store.state.selectedTaskID == todo.id)
    }

    @Test
    func macSidebarSelectionChanged_selectingRoutineFromAllKeepsAllMode() async {
        let context = makeInMemoryContext()
        let routine = makeTask(
            in: context,
            name: "Meditate",
            interval: 1,
            lastDone: nil,
            emoji: "🧘"
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [routine],
                taskListMode: .all,
                macSidebarMode: .routines
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.macSidebarSelectionChanged(.task(routine.id))) {
            $0.macSidebarSelection = .task(routine.id)
        }
        await store.receive(.setSelectedTask(routine.id))

        #expect(store.state.taskListMode == .all)
        #expect(store.state.selectedTaskID == routine.id)
    }

    @Test
    func macNavigationRouter_settingsModeDefaultsSectionAndDismissesAddSheet() {
        let persistedModes = LockIsolated<[HomeFeature.MacSidebarMode]>([])
        let router = HomeFeatureMacNavigationRouter(
            setHideUnavailableRoutines: { _ in },
            persistTemporaryViewState: { state in
                let mode = state.macSidebarMode
                persistedModes.withValue { $0.append(mode) }
            }
        )
        var state = HomeFeature.State(
            selectedTaskID: UUID(),
            isAddRoutineSheetPresented: true,
            selectedSettingsSection: nil
        )

        _ = router.sidebarModeChanged(.settings, state: &state)

        #expect(state.macSidebarMode == .settings)
        #expect(state.selectedSettingsSection == .notifications)
        #expect(state.selectedTaskID == nil)
        #expect(state.macSidebarSelection == nil)
        #expect(!state.isAddRoutineSheetPresented)
        #expect(persistedModes.value == [.settings])
    }

    @Test
    func macNavigationRouter_boardModeClearsRoutineSelection() {
        let routine = RoutineTask(name: "Meditate", scheduleMode: .fixedInterval, createdAt: nil)
        let router = HomeFeatureMacNavigationRouter(
            setHideUnavailableRoutines: { _ in },
            persistTemporaryViewState: { _ in }
        )
        var state = HomeFeature.State(
            routineTasks: [routine],
            selectedTaskID: routine.id,
            taskDetailState: TaskDetailFeature.State(task: routine),
            taskListMode: .routines,
            macSidebarSelection: .task(routine.id)
        )

        _ = router.sidebarModeChanged(.board, state: &state)

        #expect(state.macSidebarMode == .board)
        #expect(state.selectedTaskID == nil)
        #expect(state.taskDetailState == nil)
        #expect(state.macSidebarSelection == nil)
    }

    @Test
    func macBoardCommandRouterRoutesBoardScopeAndSprintDraftState() {
        let sprintID = UUID()
        let taskID = UUID()
        let recorder = MacBoardCommandRouterRecorder()
        let router = makeMacBoardCommandRouter(recorder: recorder)
        var state = HomeFeature.State(
            sprintBoardData: SprintBoardData(
                sprints: [
                    BoardSprint(id: sprintID, title: "Launch")
                ]
            ),
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(task: RoutineTask(id: taskID, name: "Todo", scheduleMode: .oneOff)),
            macSidebarSelection: .task(taskID)
        )

        _ = router.selectedBoardScopeChanged(HomeFeature.BoardScope.sprint(sprintID), state: &state)
        #expect(state.selectedBoardScope == HomeFeature.BoardScope.sprint(sprintID))
        #expect(state.selectedTaskID == nil)
        #expect(state.taskDetailState == nil)
        #expect(state.macSidebarSelection == nil)

        _ = router.createSprintTapped(state: &state)
        #expect(state.creatingSprintTitle == "")

        _ = router.createSprintTitleChanged("Refactor", state: &state)
        _ = router.createSprintConfirmed(state: &state)
        #expect(recorder.createdSprintTitles == ["Refactor"])

        _ = router.renameSprintTapped(sprintID, state: &state)
        #expect(state.renamingSprintID == sprintID)
        #expect(state.renamingSprintTitle == "Launch")

        _ = router.renamingSprintTitleChanged("Launch v2", state: &state)
        _ = router.renameSprintConfirmed(state: &state)
        #expect(recorder.renamedSprints == [MacBoardCommandRouterRecorder.RenamedSprint(id: sprintID, title: "Launch v2")])

        _ = router.deleteSprintTapped(sprintID, state: &state)
        #expect(state.deletingSprintID == sprintID)

        _ = router.deleteSprintCanceled(state: &state)
        #expect(state.deletingSprintID == nil)
    }

    @Test
    func taskListModeChanged_hidesMacFilterDetail() async {
        let context = makeInMemoryContext()
        let store = TestStore(
            initialState: HomeFeature.State(isMacFilterDetailPresented: true)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            $0.isMacFilterDetailPresented = false
        }
    }
}

private final class MacBoardCommandRouterRecorder {
    struct RenamedSprint: Equatable {
        let id: UUID
        let title: String
    }

    var movedTodoStates: [(UUID, TodoState)] = []
    var boardMoves: [(taskID: UUID, targetState: TodoState, orderedTaskIDs: [UUID])] = []
    var createdBacklogTitles: [String] = []
    var createdSprintTitles: [String] = []
    var startedSprintIDs: [UUID] = []
    var finishedSprintIDs: [UUID] = []
    var backlogAssignments: [(taskID: UUID, backlogID: UUID?)] = []
    var bulkBacklogAssignments: [(taskIDs: [UUID], backlogID: UUID?)] = []
    var sprintAssignments: [(taskID: UUID, sprintID: UUID?)] = []
    var bulkSprintAssignments: [(taskIDs: [UUID], sprintID: UUID?)] = []
    var renamedSprints: [RenamedSprint] = []
    var deletedSprintIDs: [UUID] = []
}

private func makeMacBoardCommandRouter(
    recorder: MacBoardCommandRouterRecorder
) -> HomeFeatureMacBoardCommandRouter {
    HomeFeatureMacBoardCommandRouter(
        moveTodoToState: { id, state, _ in
            recorder.movedTodoStates.append((id, state))
            return .none
        },
        moveTodoOnBoard: { taskID, targetState, orderedTaskIDs, _ in
            recorder.boardMoves.append((taskID, targetState, orderedTaskIDs))
            return .none
        },
        createBacklog: { title, _ in
            recorder.createdBacklogTitles.append(title)
            return .none
        },
        createSprint: { title, _ in
            recorder.createdSprintTitles.append(title)
            return .none
        },
        startSprint: { sprintID, _ in
            recorder.startedSprintIDs.append(sprintID)
            return .none
        },
        finishSprint: { sprintID, _ in
            recorder.finishedSprintIDs.append(sprintID)
            return .none
        },
        assignTodoToBacklog: { taskID, backlogID, _ in
            recorder.backlogAssignments.append((taskID, backlogID))
            return .none
        },
        assignTodosToBacklog: { taskIDs, backlogID, _ in
            recorder.bulkBacklogAssignments.append((taskIDs, backlogID))
            return .none
        },
        assignTodoToSprint: { taskID, sprintID, _ in
            recorder.sprintAssignments.append((taskID, sprintID))
            return .none
        },
        assignTodosToSprint: { taskIDs, sprintID, _ in
            recorder.bulkSprintAssignments.append((taskIDs, sprintID))
            return .none
        },
        renameSprint: { id, title, _ in
            recorder.renamedSprints.append(.init(id: id, title: title))
            return .none
        },
        deleteSprint: { id, _ in
            recorder.deletedSprintIDs.append(id)
            return .none
        }
    )
}
