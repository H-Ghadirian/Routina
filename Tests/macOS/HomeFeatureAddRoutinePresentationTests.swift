import ComposableArchitecture
import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct HomeFeatureAddRoutinePresentationTests {
    @Test
    func setAddRoutineSheet_togglesPresentationAndChildState() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setAddRoutineSheet(true)) {
            $0.isAddRoutineSheetPresented = true
            $0.addRoutineState = AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(
                    availableTagSummaries: [],
                    existingRoutineNames: []
                )
            )
        }

        await store.send(.setAddRoutineSheet(false)) {
            $0.isAddRoutineSheetPresented = false
            $0.addRoutineState = nil
        }
    }

    @Test
    func setAddRoutineSheet_seedsExistingNamesFromLoadedTasks() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚", tags: ["Learning"])

        let initialState = HomeFeature.State(
            routineTasks: [task],
            routineDisplays: [],
            doneStats: HomeFeature.DoneStats(totalCount: 4, countsByTaskID: [task.id: 4]),
            isAddRoutineSheetPresented: false,
            addRoutineState: nil
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setAddRoutineSheet(true)) {
            $0.isAddRoutineSheetPresented = true
            $0.addRoutineState = AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(
                    availableTags: ["Learning"],
                    availableTagSummaries: [
                        RoutineTagSummary(name: "Learning", linkedRoutineCount: 1, doneCount: 4)
                    ],
                    availableRelationshipTasks: [
                        RoutineTaskRelationshipCandidate(
                            id: task.id,
                            name: "Read",
                            emoji: "📚",
                            relationships: []
                        )
                    ],
                    existingRoutineNames: ["Read"]
                )
            )
        }
    }

    @Test
    func setAddRoutineSheet_hidesMacFilterDetail() async {
        let context = makeInMemoryContext()

        let store = TestStore(
            initialState: HomeFeature.State(isMacFilterDetailPresented: true)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setAddRoutineSheet(true)) {
            $0.isAddRoutineSheetPresented = true
            $0.isMacFilterDetailPresented = false
            $0.addRoutineState = AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(
                    availableTagSummaries: [],
                    existingRoutineNames: []
                )
            )
        }
    }

    @Test
    func openAddLinkedTask_presentsAddRoutineSeededWithInverseRelationship() async throws {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Office")
        let currentTask = makeTask(
            in: context,
            name: "Draft report",
            interval: 2,
            lastDone: nil,
            emoji: "📝",
            placeID: place.id,
            tags: ["Focus"]
        )
        let relatedTask = makeTask(
            in: context,
            name: "Review draft",
            interval: 3,
            lastDone: nil,
            emoji: "🔍",
            placeID: place.id,
            tags: ["Writing"]
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [currentTask, relatedTask],
                routinePlaces: [place],
                selectedTaskID: currentTask.id,
                taskDetailState: TaskDetailFeature.State(
                    task: currentTask,
                    addLinkedTaskRelationshipKind: .blockedBy
                ),
                isMacFilterDetailPresented: true
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(HomeFeature.Action.taskDetail(.openAddLinkedTask)) {
            $0.isAddRoutineSheetPresented = true
            $0.isMacFilterDetailPresented = false
            $0.addRoutineState = AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(
                    relationships: [RoutineTaskRelationship(targetTaskID: currentTask.id, kind: .blocks)],
                    availableTags: ["Focus", "Writing"],
                    availableTagSummaries: [
                        RoutineTagSummary(name: "Focus", linkedRoutineCount: 1, doneCount: 0),
                        RoutineTagSummary(name: "Writing", linkedRoutineCount: 1, doneCount: 0)
                    ],
                    availableRelationshipTasks: [
                        RoutineTaskRelationshipCandidate(
                            id: relatedTask.id,
                            name: "Review draft",
                            emoji: "🔍",
                            relationships: [],
                            status: .onTrack
                        )
                    ],
                    existingRoutineNames: ["Draft report", "Review draft"],
                    availablePlaces: [
                        RoutinePlaceSummary(
                            id: place.id,
                            name: "Office",
                            radiusMeters: place.radiusMeters,
                            linkedRoutineCount: 2
                        )
                    ]
                )
            )
        }

        let addRoutineState = try #require(store.state.addRoutineState)
        #expect(addRoutineState.organization.relationships == [
            RoutineTaskRelationship(targetTaskID: currentTask.id, kind: .blocks)
        ])
        #expect(addRoutineState.organization.availableTags == ["Focus", "Writing"])
        #expect(addRoutineState.organization.existingRoutineNames == ["Draft report", "Review draft"])
        #expect(addRoutineState.organization.availablePlaces == [
            RoutinePlaceSummary(
                id: place.id,
                name: "Office",
                radiusMeters: place.radiusMeters,
                linkedRoutineCount: 2
            )
        ])
        #expect(addRoutineState.organization.availableRelationshipTasks == [
            RoutineTaskRelationshipCandidate(
                id: relatedTask.id,
                name: "Review draft",
                emoji: "🔍",
                relationships: [],
                status: .onTrack
            )
        ])
    }
}
