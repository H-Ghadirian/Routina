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
struct HomeFeatureAddRoutinePresentationRouterTests {
    @Test
    func setSheetPresentsPreparedAddRoutineStateAndHidesFilterDetail() {
        let task = RoutineTask(id: UUID(), name: "Focus", emoji: "F", tags: ["Deep"])
        let place = RoutinePlace(name: "Office", latitude: 52.52, longitude: 13.405)
        let goal = RoutineGoal(title: "Launch")
        var state = TestAddRoutinePresentationState(
            routineTasks: [task],
            routinePlaces: [place],
            routineGoals: [goal],
            doneStats: HomeDoneStats(totalCount: 1, countsByTaskID: [task.id: 1]),
            presentation: HomePresentationState(isMacFilterDetailPresented: true)
        )

        makeRouter().setSheet(true, state: &state)

        #expect(state.presentation.isAddRoutineSheetPresented)
        #expect(!state.presentation.isMacFilterDetailPresented)
        #expect(state.presentation.addRoutineState?.organization.availableTags == ["Deep"])
        #expect(state.presentation.addRoutineState?.organization.existingRoutineNames == ["Focus"])
        #expect(state.presentation.addRoutineState?.organization.availablePlaces.map(\.name) == ["Office"])
        #expect(state.presentation.addRoutineState?.organization.availableGoals.map(\.title) == ["Launch"])
    }

    @Test
    func openLinkedTaskSheetPreselectsInverseRelationshipAndExcludesCurrentTask() {
        let currentTask = RoutineTask(id: UUID(), name: "Current", emoji: "C")
        let otherTask = RoutineTask(id: UUID(), name: "Other", emoji: "O")
        var detailState = TaskDetailFeature.State(task: currentTask)
        detailState.addLinkedTaskRelationshipKind = .blockedBy
        var state = TestAddRoutinePresentationState(
            routineTasks: [currentTask, otherTask],
            selection: HomeSelectionState(
                selectedTaskID: currentTask.id,
                taskDetailState: detailState
            )
        )

        let didOpen = makeRouter().openLinkedTaskSheet(state: &state)

        #expect(didOpen)
        #expect(state.presentation.isAddRoutineSheetPresented)
        #expect(state.presentation.addRoutineState?.organization.relationships == [
            RoutineTaskRelationship(targetTaskID: currentTask.id, kind: .blocks)
        ])
        #expect(state.presentation.addRoutineState?.organization.availableRelationshipTasks.map(\.id) == [otherTask.id])
    }

    @Test
    func dismissSheetClearsPresentationState() {
        var state = TestAddRoutinePresentationState(
            presentation: HomePresentationState(
                isAddRoutineSheetPresented: true,
                addRoutineState: AddRoutineFeature.State()
            )
        )

        makeRouter().dismissSheet(state: &state)

        #expect(!state.presentation.isAddRoutineSheetPresented)
        #expect(state.presentation.addRoutineState == nil)
    }

    private func makeRouter() -> HomeFeatureAddRoutinePresentationRouter<TestAddRoutinePresentationState> {
        HomeFeatureAddRoutinePresentationRouter(
            tagCounterDisplayMode: { .combinedTotal },
            relatedTagRules: { [RoutineRelatedTagRule(tag: "Deep", relatedTags: ["Work"])] }
        )
    }
}

private struct TestAddRoutinePresentationState: HomeFeatureAddRoutinePresentationState, Equatable {
    var routineTasks: [RoutineTask] = []
    var routinePlaces: [RoutinePlace] = []
    var routineGoals: [RoutineGoal] = []
    var doneStats = HomeDoneStats()
    var selection = HomeSelectionState()
    var presentation = HomePresentationState()
}
