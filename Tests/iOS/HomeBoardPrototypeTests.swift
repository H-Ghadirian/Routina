import ComposableArchitecture
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
    func moveTodoToState_fromPausedToInProgress_clearsPause() async {
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
                taskListMode: .all,
                selectedTaskID: todo.id
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.macSidebarModeChanged(.board)) {
            $0.macSidebarMode = .board
            $0.macSidebarSelection = .task(todo.id)
        }
        await store.receive(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
        }
    }
}
