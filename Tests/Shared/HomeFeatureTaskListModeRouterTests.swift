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
struct HomeFeatureTaskListModeRouterTests {
    @Test
    func changeModeResetsUnavailableFilterClearsInvalidSelectionAndPersistsState() {
        let routine = RoutineTask(id: UUID(), name: "Routine", emoji: "R")
        var state = TestTaskListModeRoutingState(
            routineTasks: [routine],
            selection: HomeSelectionState(
                selectedTaskID: routine.id,
                taskDetailState: TaskDetailFeature.State(task: routine)
            ),
            presentation: HomePresentationState(isMacFilterDetailPresented: true),
            hideUnavailableRoutines: true,
            taskListMode: .routines
        )
        let recorder = TestTaskListModeRouterRecorder()
        let router = makeRouter(recorder)

        router.changeMode(.todos, state: &state)

        #expect(state.taskListMode == .todos)
        #expect(!state.hideUnavailableRoutines)
        #expect(!state.presentation.isMacFilterDetailPresented)
        #expect(state.selection.selectedTaskID == nil)
        #expect(state.selection.taskDetailState == nil)
        #expect(state.taskFilters.tabFilterSnapshots[TestTaskListMode.routines.rawValue] != nil)
        #expect(recorder.hiddenUnavailableValues == [false])
        #expect(recorder.didSynchronizePlatformSelection)
        #expect(recorder.persistedStates.map(\.taskListMode) == [.todos])
    }

    @Test
    func changeModeKeepsCompatibleSelectionAndSkipsPlatformSync() {
        let todo = RoutineTask(
            id: UUID(),
            name: "Todo",
            emoji: "T",
            scheduleMode: .oneOff
        )
        var state = TestTaskListModeRoutingState(
            routineTasks: [todo],
            selection: HomeSelectionState(
                selectedTaskID: todo.id,
                taskDetailState: TaskDetailFeature.State(task: todo)
            ),
            taskListMode: .all
        )
        let recorder = TestTaskListModeRouterRecorder()
        let router = makeRouter(recorder)

        router.changeMode(.todos, state: &state)

        #expect(state.taskListMode == .todos)
        #expect(state.selection.selectedTaskID == todo.id)
        #expect(!recorder.didSynchronizePlatformSelection)
        #expect(recorder.hiddenUnavailableValues.isEmpty)
        #expect(recorder.persistedStates.map(\.taskListMode) == [.todos])
    }

    private func makeRouter(_ recorder: TestTaskListModeRouterRecorder) -> HomeFeatureTaskListModeRouter<TestTaskListModeRoutingState> {
        HomeFeatureTaskListModeRouter(
            setHideUnavailableRoutines: { value in
                recorder.hiddenUnavailableValues.append(value)
            },
            persistTemporaryViewState: { state in
                recorder.persistedStates.append(state)
            },
            synchronizePlatformSelectionAfterModeChange: { _ in
                recorder.didSynchronizePlatformSelection = true
            }
        )
    }
}

private enum TestTaskListMode: String, Equatable {
    case all = "All"
    case routines = "Routines"
    case todos = "Todos"
}

private final class TestTaskListModeRouterRecorder {
    var hiddenUnavailableValues: [Bool] = []
    var didSynchronizePlatformSelection = false
    var persistedStates: [TestTaskListModeRoutingState] = []
}

private struct TestTaskListModeRoutingState: HomeFeatureTaskListModeRoutingState, Equatable {
    var routineTasks: [RoutineTask] = []
    var selection = HomeSelectionState()
    var presentation = HomePresentationState()
    var hideUnavailableRoutines = false
    var taskListMode: TestTaskListMode = .todos
    var taskFilters = HomeTaskFiltersState()
}
