import ComposableArchitecture
import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct MissingTaskMetadataFeatureTests {
    @Test
    func importanceReviewLoadsOnlyTasksWithoutExplicitImportanceInTitleOrder() async throws {
        let context = makeInMemoryContext()
        let laterTask = makeTask(in: context, name: "Write update", interval: 1, lastDone: nil, emoji: nil)
        let firstTask = makeTask(in: context, name: "Buy coffee", interval: 1, lastDone: nil, emoji: nil)
        let urgencyOnlyTask = makeTask(in: context, name: "Urgency set", interval: 1, lastDone: nil, emoji: nil)
        urgencyOnlyTask.urgency = .level4
        urgencyOnlyTask.hasExplicitUrgency = true
        urgencyOnlyTask.priority = urgencyOnlyTask.derivedPriorityFromMatrix
        let explicitImportanceTask = makeTask(in: context, name: "Importance set", interval: 1, lastDone: nil, emoji: nil)
        explicitImportanceTask.hasExplicitImportance = true
        let legacyPriorityTask = makeTask(in: context, name: "Legacy priority", interval: 1, lastDone: nil, emoji: nil)
        legacyPriorityTask.priority = .high
        let completedRepeatingTask = makeTask(
            in: context,
            name: "Finished repeating",
            interval: 1,
            lastDone: Date(timeIntervalSince1970: 1),
            emoji: nil
        )
        let openOneOffTask = makeTask(
            in: context,
            name: "Open one-off",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            scheduleMode: .oneOff
        )
        let completedOneOffTask = makeTask(
            in: context,
            name: "Completed one-off",
            interval: 1,
            lastDone: Date(timeIntervalSince1970: 1),
            emoji: nil,
            scheduleMode: .oneOff
        )
        let canceledOneOffTask = makeTask(
            in: context,
            name: "Canceled one-off",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            scheduleMode: .oneOff
        )
        canceledOneOffTask.canceledAt = Date(timeIntervalSince1970: 1)
        let archivedTask = makeTask(
            in: context,
            name: "Archived metadata task",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            scheduleMode: .oneOff
        )
        archivedTask.pausedAt = Date(timeIntervalSince1970: 1)
        try context.save()

        let store = TestStore(initialState: MissingTaskMetadataFeature.State(field: .importance)) {
            MissingTaskMetadataFeature(field: .importance)
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.calendar = Calendar(identifier: .gregorian)
        }

        let expectedTaskIDs = [
            firstTask.id,
            completedRepeatingTask.id,
            openOneOffTask.id,
            urgencyOnlyTask.id,
            laterTask.id,
        ]
        let expectedCurrentTask = MissingTaskMetadataFeature.State.Task(task: firstTask)

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(.tasksLoaded(taskIDs: expectedTaskIDs, currentTask: expectedCurrentTask)) {
            $0.taskIDs = expectedTaskIDs
            $0.currentTask = expectedCurrentTask
            $0.totalTaskCount = expectedTaskIDs.count
            $0.hasLoadedTasks = true
            $0.isLoading = false
        }

        #expect(store.state.taskIDs == expectedTaskIDs)
        #expect(store.state.currentTask == expectedCurrentTask)
        #expect(!store.state.taskIDs.contains(explicitImportanceTask.id))
        #expect(!store.state.taskIDs.contains(legacyPriorityTask.id))
        #expect(!store.state.taskIDs.contains(completedOneOffTask.id))
        #expect(!store.state.taskIDs.contains(canceledOneOffTask.id))
        #expect(!store.state.taskIDs.contains(archivedTask.id))
    }

    @Test
    func savingImportanceLeavesUrgencyEligibleAndAdvances() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Book dentist", interval: 1, lastDone: nil, emoji: nil)
        let display = MissingTaskMetadataFeature.State.Task(task: task)
        var initialState = MissingTaskMetadataFeature.State(field: .importance)
        initialState.taskIDs = [task.id]
        initialState.currentTask = display
        initialState.totalTaskCount = 1
        let store = TestStore(initialState: initialState) {
            MissingTaskMetadataFeature(field: .importance)
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.valueSelected(taskID: task.id, value: .importance(.level3))) {
            $0.isSaving = true
        }
        await store.receive(.valueSaved(taskID: task.id)) {
            $0.taskIDs = []
            $0.currentTask = nil
            $0.completedTaskCount = 1
            $0.currentTaskIndex = 0
            $0.isSaving = false
        }

        let persistedTask = try #require(
            try context.fetch(TaskDetailFetchDescriptors.task(for: task.id)).first
        )
        #expect(persistedTask.importance == .level3)
        #expect(persistedTask.urgency == .level2)
        #expect(persistedTask.hasExplicitImportance)
        #expect(!persistedTask.hasExplicitUrgency)
        #expect(TaskDetailOptionalControlVisibility.showsImportance(for: persistedTask))
        #expect(!TaskDetailOptionalControlVisibility.showsUrgency(for: persistedTask))
        let activityLogs = try context.fetch(FetchDescriptor<RoutinaDeviceActionLog>())
        #expect(
            activityLogs.contains {
                $0.action == .updated
                    && $0.entity == .task
                    && $0.entityID == task.id.uuidString
                    && $0.details == "Reviewed importance"
            }
        )
    }

    @Test
    func savingUrgencyAtTheLegacyDefaultMakesOnlyUrgencyExplicit() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Reply to email", interval: 1, lastDone: nil, emoji: nil)
        let display = MissingTaskMetadataFeature.State.Task(task: task)
        var initialState = MissingTaskMetadataFeature.State(field: .urgency)
        initialState.taskIDs = [task.id]
        initialState.currentTask = display
        initialState.totalTaskCount = 1
        let store = TestStore(initialState: initialState) {
            MissingTaskMetadataFeature(field: .urgency)
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.valueSelected(taskID: task.id, value: .urgency(.level2))) {
            $0.isSaving = true
        }
        await store.receive(.valueSaved(taskID: task.id)) {
            $0.taskIDs = []
            $0.currentTask = nil
            $0.completedTaskCount = 1
            $0.currentTaskIndex = 0
            $0.isSaving = false
        }

        let persistedTask = try #require(
            try context.fetch(TaskDetailFetchDescriptors.task(for: task.id)).first
        )
        #expect(persistedTask.urgency == .level2)
        #expect(!persistedTask.hasExplicitImportance)
        #expect(persistedTask.hasExplicitUrgency)
        #expect(!TaskDetailOptionalControlVisibility.showsImportance(for: persistedTask))
        #expect(TaskDetailOptionalControlVisibility.showsUrgency(for: persistedTask))
    }

    @Test
    func checkingTaskDetailsRequestsTheCurrentTaskDetail() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Plan trip", interval: 1, lastDone: nil, emoji: nil)
        var initialState = MissingTaskMetadataFeature.State(field: .urgency)
        initialState.taskIDs = [task.id]
        initialState.currentTask = MissingTaskMetadataFeature.State.Task(task: task)
        initialState.totalTaskCount = 1
        let store = TestStore(initialState: initialState) {
            MissingTaskMetadataFeature(field: .urgency)
        }

        await store.send(.taskDetailsTapped(taskID: task.id))
        await store.receive(.delegate(.taskDetailsRequested(task.id)))
    }

    @Test
    func iOSProcedureViewUsesAlwaysVisibleChoicesAndKeepsSwiftDataWorkInTheReducer() throws {
        let source = try Self.sourceFile("iOS/Screens/More/MissingTaskMetadataView.swift")

        #expect(source.contains("let store: StoreOf<MissingTaskMetadataFeature>"))
        #expect(source.contains("RoutinaGlassSegmentedControl"))
        #expect(source.contains("maximumSegmentsPerRow: 2"))
        #expect(source.contains("minHeight: 620"))
        #expect(source.contains("GuidedReviewProgressHeader"))
        #expect(source.contains("navigationTitleClearance"))
        #expect(source.contains(".padding(.top, navigationTitleClearance)"))
        #expect(source.contains("store.send(.valueSelected"))
        #expect(source.contains("store.send(.skipTask"))
        #expect(source.contains("store.send(.taskDetailsTapped"))
        #expect(!source.contains("Menu"))
        #expect(!source.contains("@Query"))
        #expect(!source.contains("@Environment(\\.modelContext)"))
        #expect(!source.contains("modelContext.save()"))
        #expect(!source.contains("ScrollView"))
        #expect(!source.contains("DragGesture"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
