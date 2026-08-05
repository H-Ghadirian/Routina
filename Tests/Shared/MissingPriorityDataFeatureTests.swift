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
struct MissingPriorityDataFeatureTests {
    @Test
    func onAppear_loadsOnlyTasksWhosePriorityDetailIsHiddenInTitleOrder() async throws {
        let context = makeInMemoryContext()
        let laterTask = makeTask(
            in: context,
            name: "Write update",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let firstTask = makeTask(
            in: context,
            name: "Buy coffee",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
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
        let explicitlyRevealedTask = makeTask(
            in: context,
            name: "Explicit medium",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        explicitlyRevealedTask.showsTaskDetailPriority = true
        let importantTask = makeTask(
            in: context,
            name: "Important task",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        importantTask.importance = .level3
        let prioritizedTask = makeTask(
            in: context,
            name: "Prioritized task",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        prioritizedTask.priority = .high
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
        try context.save()

        let store = TestStore(initialState: MissingPriorityDataFeature.State()) {
            MissingPriorityDataFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.calendar = Calendar(identifier: .gregorian)
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(
            .tasksLoaded([
                MissingPriorityDataFeature.State.Task(task: firstTask),
                MissingPriorityDataFeature.State.Task(task: completedRepeatingTask),
                MissingPriorityDataFeature.State.Task(task: openOneOffTask),
                MissingPriorityDataFeature.State.Task(task: laterTask),
            ])
        ) {
            $0.tasks = [
                MissingPriorityDataFeature.State.Task(task: firstTask),
                MissingPriorityDataFeature.State.Task(task: completedRepeatingTask),
                MissingPriorityDataFeature.State.Task(task: openOneOffTask),
                MissingPriorityDataFeature.State.Task(task: laterTask),
            ]
            $0.totalTaskCount = 4
            $0.hasLoadedTasks = true
            $0.isLoading = false
        }

        #expect(
            store.state.tasks.map(\.id)
                == [firstTask.id, completedRepeatingTask.id, openOneOffTask.id, laterTask.id]
        )
        #expect(!store.state.tasks.contains(where: { $0.id == explicitlyRevealedTask.id }))
        #expect(!store.state.tasks.contains(where: { $0.id == importantTask.id }))
        #expect(!store.state.tasks.contains(where: { $0.id == prioritizedTask.id }))
        #expect(!store.state.tasks.contains(where: { $0.id == completedOneOffTask.id }))
        #expect(!store.state.tasks.contains(where: { $0.id == canceledOneOffTask.id }))
    }

    @Test
    func savingPriorityValues_makesThePriorityDetailExplicitAndAdvances() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Book dentist",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let display = MissingPriorityDataFeature.State.Task(task: task)
        let store = TestStore(
            initialState: MissingPriorityDataFeature.State(tasks: [display], totalTaskCount: 1)
        ) {
            MissingPriorityDataFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.importanceSelected(.level3)) {
            $0.selectedImportance = .level3
        }
        await store.send(.urgencySelected(.level4)) {
            $0.selectedUrgency = .level4
        }
        await store.send(.saveSelected(taskID: task.id)) {
            $0.isSaving = true
        }
        await store.receive(.valuesSaved(taskID: task.id)) {
            $0.tasks = []
            $0.completedTaskCount = 1
            $0.currentTaskIndex = 0
            $0.selectedImportance = .level2
            $0.selectedUrgency = .level2
            $0.isSaving = false
        }

        let persistedTask = try #require(
            try context.fetch(TaskDetailFetchDescriptors.task(for: task.id)).first
        )
        #expect(persistedTask.importance == .level3)
        #expect(persistedTask.urgency == .level4)
        #expect(persistedTask.priority == .urgent)
        #expect(persistedTask.showsTaskDetailPriority)
        #expect(TaskDetailOptionalControlVisibility.showsPriority(for: persistedTask))
        let activityLogs = try context.fetch(FetchDescriptor<RoutinaDeviceActionLog>())
        #expect(
            activityLogs.contains {
                $0.action == .updated
                    && $0.entity == .task
                    && $0.entityID == task.id.uuidString
                    && $0.details == "Reviewed importance and urgency"
            }
        )
    }

    @Test
    func checkingTaskDetails_requestsTheCurrentTaskDetail() async {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Plan trip",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let display = MissingPriorityDataFeature.State.Task(task: task)
        let store = TestStore(
            initialState: MissingPriorityDataFeature.State(tasks: [display], totalTaskCount: 1)
        ) {
            MissingPriorityDataFeature()
        }

        await store.send(.taskDetailsTapped(taskID: task.id))
        await store.receive(.delegate(.taskDetailsRequested(task.id)))
    }

    @Test
    func iOSProcedureViewKeepsSwiftDataWorkInTheReducer() throws {
        let source = try Self.sourceFile("iOS/Screens/More/MissingPriorityDataView.swift")

        #expect(source.contains("let store: StoreOf<MissingPriorityDataFeature>"))
        #expect(source.contains("store.send(.importanceSelected"))
        #expect(source.contains("store.send(.urgencySelected"))
        #expect(source.contains("store.send(.saveSelected"))
        #expect(source.contains("store.send(.skipTask"))
        #expect(source.contains("store.send(.taskDetailsTapped"))
        #expect(!source.contains("@Query"))
        #expect(!source.contains("@Environment(\\.modelContext)"))
        #expect(!source.contains("modelContext.save()"))
        #expect(!source.contains("ScrollView"))
        #expect(!source.contains("DragGesture"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
