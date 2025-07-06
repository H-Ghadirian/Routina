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

    @Test
    func moveTodoOnBoard_reordersWithinSameColumn() async {
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
            setTestDateDependencies(&$0)
        }

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
            setTestDateDependencies(&$0)
        }

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
}
