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
struct HomeFeatureTaskLoadHandlerTests {
    @Test
    func applyLoadedTasksHydratesStateAndRunsInjectedCallbacks() {
        let taskID = UUID()
        let placeID = UUID()
        let goalID = UUID()
        let olderLogDate = makeDate("2026-03-20T08:00:00Z")
        let newerLogDate = makeDate("2026-03-21T08:00:00Z")
        let task = RoutineTask(
            id: taskID,
            name: "Focus",
            emoji: "🎯",
            placeID: placeID,
            tags: ["Focus"],
            goalIDs: [goalID]
        )
        let place = RoutinePlace(
            id: placeID,
            name: "Office",
            latitude: 52.52,
            longitude: 13.405
        )
        let goal = RoutineGoal(id: goalID, title: "Deep work")
        let olderLog = RoutineLog(timestamp: olderLogDate, taskID: taskID)
        let newerLog = RoutineLog(timestamp: newerLogDate, taskID: taskID)
        let doneStats = HomeDoneStats(totalCount: 2, countsByTaskID: [taskID: 2])
        var state = TestTaskLoadState()
        let recorder = TestTaskLoadRecorder()
        let handler = makeHandler(recorder)

        _ = handler.applyLoadedTasks(
            tasks: [task],
            places: [place],
            goals: [goal],
            logs: [olderLog, newerLog],
            doneStats: doneStats,
            state: &state
        )

        #expect(state.routineTasks.map(\.id) == [taskID])
        #expect(state.routinePlaces.map(\.id) == [placeID])
        #expect(state.routineGoals.map(\.id) == [goalID])
        #expect(state.timelineLogs.map(\.timestamp) == [newerLogDate, olderLogDate])
        #expect(state.doneStats == doneStats)
        #expect(state.relatedTagRules == [RoutineRelatedTagRule(tag: "Focus", relatedTags: ["Planning"])])
        #expect(state.tagColors == ["Focus": "#112233", "validated": "true"])
        #expect(recorder.events == ["refresh", "sync", "validate", "persist", "detail"])
        #expect(recorder.persistedStates.map(\.routineTasks.count) == [1])
        #expect(recorder.persistedStates.first?.tagColors["validated"] == "true")
    }

    private func makeHandler(_ recorder: TestTaskLoadRecorder) -> HomeFeatureTaskLoadHandler<TestTaskLoadState, TestTaskLoadAction> {
        HomeFeatureTaskLoadHandler(
            relatedTagRules: { [RoutineRelatedTagRule(tag: "Focus", relatedTags: ["Planning"])] },
            tagColors: { ["Focus": "#112233"] },
            refreshDisplays: { state in
                recorder.events.append("refresh")
                state.tagColors["refresh"] = "true"
            },
            syncSelectedTaskDetailState: { _ in
                recorder.events.append("sync")
            },
            validateFilterState: { state in
                recorder.events.append("validate")
                state.tagColors.removeValue(forKey: "refresh")
                state.tagColors["validated"] = "true"
            },
            persistTemporaryViewState: { state in
                recorder.events.append("persist")
                recorder.persistedStates.append(state)
            },
            refreshSelectedTaskDetailEffect: { _ in
                recorder.events.append("detail")
                return .send(.detailRefresh)
            },
            addRoutineAction: { .addRoutine($0) }
        )
    }
}

private enum TestTaskLoadAction: Equatable {
    case detailRefresh
    case addRoutine(AddRoutineFeature.Action)
}

private final class TestTaskLoadRecorder {
    var events: [String] = []
    var persistedStates: [TestTaskLoadState] = []
}

private struct TestTaskLoadState: HomeFeatureTaskLoadState, Equatable {
    var routineTasks: [RoutineTask] = []
    var routinePlaces: [RoutinePlace] = []
    var routineGoals: [RoutineGoal] = []
    var timelineLogs: [RoutineLog] = []
    var doneStats = HomeDoneStats()
    var selection = HomeSelectionState()
    var presentation = HomePresentationState()
    var relatedTagRules: [RoutineRelatedTagRule] = []
    var tagColors: [String: String] = [:]
}
