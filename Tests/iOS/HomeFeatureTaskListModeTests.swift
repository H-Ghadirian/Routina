import ComposableArchitecture
import Foundation
import Testing
@testable @preconcurrency import Routina

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
