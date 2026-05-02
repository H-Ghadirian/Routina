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
struct HomeFeaturePostMutationRefresherTests {
    @Test
    func finishMutationRefreshesDisplaysAndSelection() {
        var state = TestPostMutationState()
        let recorder = TestPostMutationRecorder()
        let refresher = makeRefresher(recorder)

        _ = refresher.finishMutation(.send(.primary), state: &state)

        #expect(recorder.events == ["refresh", "sync"])
        #expect(state.didRefreshDisplays)
        #expect(state.didSyncSelection)
        #expect(recorder.addRoutineActions.isEmpty)
    }

    @Test
    func finishMutationBuildsAddRoutineAvailabilityRefreshOnlyWhenRequestedAndPresented() {
        let task = RoutineTask(name: "Focus", emoji: "🎯", tags: ["Deep Work"])
        let place = RoutinePlace(name: "Office", latitude: 52.52, longitude: 13.405)
        let goal = RoutineGoal(title: "Launch")
        var state = TestPostMutationState(
            routineTasks: [task],
            routinePlaces: [place],
            routineGoals: [goal],
            doneStats: HomeDoneStats(totalCount: 1, countsByTaskID: [task.id: 1]),
            presentation: HomePresentationState(addRoutineState: AddRoutineFeature.State())
        )
        let recorder = TestPostMutationRecorder()
        let refresher = makeRefresher(recorder)

        _ = refresher.finishMutation(
            .send(.primary),
            state: &state,
            refreshAddRoutineAvailability: true
        )

        #expect(recorder.events == ["refresh", "sync"])
        #expect(recorder.addRoutineActions.count == 5)
        #expect(recorder.addRoutineActions.contains(.existingRoutineNamesChanged(["Focus"])))
        #expect(recorder.addRoutineActions.contains { action in
            guard case let .availablePlacesChanged(places) = action else { return false }
            return places.map(\.name) == ["Office"]
        })
        #expect(recorder.addRoutineActions.contains { action in
            guard case let .availableGoalsChanged(goals) = action else { return false }
            return goals.map(\.title) == ["Launch"]
        })
    }

    @Test
    func finishMutationSkipsAddRoutineAvailabilityWhenSheetIsClosed() {
        var state = TestPostMutationState()
        let recorder = TestPostMutationRecorder()
        let refresher = makeRefresher(recorder)

        _ = refresher.finishMutation(
            .send(.primary),
            state: &state,
            refreshAddRoutineAvailability: true
        )

        #expect(recorder.events == ["refresh", "sync"])
        #expect(recorder.addRoutineActions.isEmpty)
    }

    private func makeRefresher(_ recorder: TestPostMutationRecorder) -> HomeFeaturePostMutationRefresher<TestPostMutationState, TestPostMutationAction> {
        HomeFeaturePostMutationRefresher(
            refreshDisplays: { state in
                recorder.events.append("refresh")
                state.didRefreshDisplays = true
            },
            syncSelectedTaskDetailState: { state in
                recorder.events.append("sync")
                state.didSyncSelection = true
            },
            addRoutineAction: {
                recorder.addRoutineActions.append($0)
                return .addRoutine($0)
            }
        )
    }
}

private enum TestPostMutationAction: Equatable {
    case primary
    case addRoutine(AddRoutineFeature.Action)
}

private final class TestPostMutationRecorder {
    var events: [String] = []
    var addRoutineActions: [AddRoutineFeature.Action] = []
}

private struct TestPostMutationState: HomeFeaturePostMutationRefreshState, Equatable {
    var routineTasks: [RoutineTask] = []
    var routinePlaces: [RoutinePlace] = []
    var routineGoals: [RoutineGoal] = []
    var doneStats = HomeDoneStats()
    var presentation = HomePresentationState()
    var didRefreshDisplays = false
    var didSyncSelection = false
}
