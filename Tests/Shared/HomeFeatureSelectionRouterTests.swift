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
struct HomeFeatureSelectionRouterTests {
    @Test
    func setSelectedTaskSelectsTaskHidesFilterDetailAndRunsPlatformHook() {
        let task = RoutineTask(id: UUID(), name: "Focus", emoji: "F")
        var state = TestSelectionRoutingState(
            routineTasks: [task],
            presentation: HomePresentationState(isMacFilterDetailPresented: true)
        )
        let recorder = TestSelectionRouterRecorder()
        let router = makeRouter(recorder)

        _ = router.setSelectedTask(task.id, state: &state)

        #expect(state.selection.selectedTaskID == task.id)
        #expect(state.selection.taskDetailState?.task.id == task.id)
        #expect(!state.presentation.isMacFilterDetailPresented)
        #expect(recorder.platformSelections == [task.id])
        #expect(recorder.madeDetailStateTaskIDs == [task.id])
    }

    @Test
    func setSelectedTaskForAlreadySelectedTaskOnlyClosesFilterDetail() {
        let task = RoutineTask(id: UUID(), name: "Focus", emoji: "F")
        var state = TestSelectionRoutingState(
            routineTasks: [task],
            selection: HomeSelectionState(
                selectedTaskID: task.id,
                taskDetailState: TaskDetailFeature.State(task: task)
            ),
            presentation: HomePresentationState(isMacFilterDetailPresented: true)
        )
        let recorder = TestSelectionRouterRecorder()
        let router = makeRouter(recorder)

        _ = router.setSelectedTask(task.id, state: &state)

        #expect(state.selection.selectedTaskID == task.id)
        #expect(state.selection.taskDetailState?.task.id == task.id)
        #expect(!state.presentation.isMacFilterDetailPresented)
        #expect(recorder.platformSelections.isEmpty)
        #expect(recorder.madeDetailStateTaskIDs.isEmpty)
    }

    @Test
    func setSelectedTaskPopulatesLightweightDisplayContext() throws {
        let taskID = UUID()
        let directRelationshipID = UUID()
        let inverseRelationshipID = UUID()
        let unrelatedID = UUID()
        let placeID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Focus",
            emoji: "F",
            placeID: placeID,
            relationships: [
                RoutineTaskRelationship(targetTaskID: directRelationshipID, kind: .blockedBy)
            ]
        )
        let directRelationshipTask = RoutineTask(id: directRelationshipID, name: "Direct", emoji: "D")
        let inverseRelationshipTask = RoutineTask(
            id: inverseRelationshipID,
            name: "Inverse",
            emoji: "I",
            relationships: [
                RoutineTaskRelationship(targetTaskID: taskID, kind: .blocks)
            ]
        )
        let unrelatedTask = RoutineTask(id: unrelatedID, name: "Elsewhere", emoji: "E")
        let place = RoutinePlace(id: placeID, name: "Desk", latitude: 1, longitude: 2)
        var state = TestSelectionRoutingState(
            routineTasks: [task, directRelationshipTask, inverseRelationshipTask, unrelatedTask],
            routinePlaces: [place]
        )
        let router = makeRouter(TestSelectionRouterRecorder())

        _ = router.setSelectedTask(taskID, state: &state)

        let detailState = try #require(state.selection.taskDetailState)
        #expect(Set(detailState.availableRelationshipTasks.map(\.id)) == [directRelationshipID, inverseRelationshipID])
        #expect(!detailState.availableRelationshipTasks.contains(where: { $0.id == unrelatedID }))
        #expect(detailState.availablePlaces == [
            RoutinePlaceSummary(id: placeID, name: "Desk", radiusMeters: 150, linkedRoutineCount: 1)
        ])
    }

    @Test
    func syncSelectedTaskFromTaskDetailCopiesDetailTaskAndRefreshesDisplays() {
        let taskID = UUID()
        let original = RoutineTask(id: taskID, name: "Original", emoji: "O")
        let edited = RoutineTask(id: taskID, name: "Edited", emoji: "E", tags: ["Updated"])
        var state = TestSelectionRoutingState(
            routineTasks: [original],
            selection: HomeSelectionState(
                selectedTaskID: taskID,
                taskDetailState: TaskDetailFeature.State(task: edited)
            )
        )
        let recorder = TestSelectionRouterRecorder()
        let router = makeRouter(recorder)

        router.syncSelectedTaskFromTaskDetail(&state)

        #expect(state.routineTasks.first?.name == "Edited")
        #expect(state.routineTasks.first?.tags == ["Updated"])
        #expect(recorder.didRefreshDisplays)
    }

    private func makeRouter(_ recorder: TestSelectionRouterRecorder) -> HomeFeatureSelectionRouter<TestSelectionRoutingState, TestSelectionAction> {
        HomeFeatureSelectionRouter(
            now: makeDate("2026-03-20T10:00:00Z"),
            calendar: makeTestCalendar(),
            makeTaskDetailState: { task in
                recorder.madeDetailStateTaskIDs.append(task.id)
                return TaskDetailFeature.State(task: task)
            },
            refreshDisplays: { _ in
                recorder.didRefreshDisplays = true
            },
            refreshTaskDetailAction: { .refreshDetail },
            synchronizePlatformSelection: { _, taskID in
                recorder.platformSelections.append(taskID)
            }
        )
    }
}

private enum TestSelectionAction: Equatable {
    case refreshDetail
}

private final class TestSelectionRouterRecorder {
    var madeDetailStateTaskIDs: [UUID] = []
    var platformSelections: [UUID?] = []
    var didRefreshDisplays = false
}

private struct TestSelectionRoutingState: HomeFeatureSelectionRoutingState, Equatable {
    var routineTasks: [RoutineTask] = []
    var routinePlaces: [RoutinePlace] = []
    var selection = HomeSelectionState()
    var presentation = HomePresentationState()
}
