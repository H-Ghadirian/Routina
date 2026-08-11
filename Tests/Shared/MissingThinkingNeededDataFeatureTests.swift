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
struct MissingThinkingNeededDataFeatureTests {
    @Test
    func onAppear_loadsOnlyTasksWithMissingThinkingNeededInTitleOrder() async throws {
        let context = makeInMemoryContext()
        let laterTask = makeTask(in: context, name: "Write proposal", interval: 1, lastDone: nil, emoji: nil)
        let firstTask = makeTask(in: context, name: "Call lawyer", interval: 1, lastDone: nil, emoji: nil)
        let assignedTask = makeTask(in: context, name: "Easy cleaning", interval: 1, lastDone: nil, emoji: nil)
        assignedTask.thinkingNeeded = .low
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
            name: "Archived thinking task",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            scheduleMode: .oneOff
        )
        archivedTask.pausedAt = Date(timeIntervalSince1970: 1)
        try context.save()

        let store = TestStore(
            initialState: MissingTaskDataFeature.State(field: .thinkingNeeded)
        ) {
            MissingTaskDataFeature(field: .thinkingNeeded)
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.calendar = Calendar(identifier: .gregorian)
        }

        let expectedTaskIDs = [
            firstTask.id,
            completedRepeatingTask.id,
            openOneOffTask.id,
            laterTask.id,
        ]
        let expectedCurrentTask = MissingTaskDataFeature.State.Task(task: firstTask)

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

        #expect(!store.state.taskIDs.contains(assignedTask.id))
        #expect(!store.state.taskIDs.contains(completedOneOffTask.id))
        #expect(!store.state.taskIDs.contains(canceledOneOffTask.id))
        #expect(!store.state.taskIDs.contains(archivedTask.id))
    }

    @Test
    func selectingThinkingNeeded_savesOnlyTheThinkingNeededValueAndAdvances() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Prepare tax documents", interval: 1, lastDone: nil, emoji: nil)
        let display = MissingTaskDataFeature.State.Task(task: task)
        let store = TestStore(
            initialState: MissingTaskDataFeature.State(
                field: .thinkingNeeded,
                taskIDs: [task.id],
                currentTask: display,
                totalTaskCount: 1
            )
        ) {
            MissingTaskDataFeature(field: .thinkingNeeded)
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.valueSelected(taskID: task.id, value: .thinkingNeeded(.high))) {
            $0.isSaving = true
        }
        await store.receive(.valueSaved(taskID: task.id)) {
            $0.taskIDs = []
            $0.currentTask = nil
            $0.completedTaskCount = 1
            $0.currentTaskIndex = 0
            $0.isSaving = false
        }

        let savedTask = try #require(
            try context.fetch(TaskDetailFetchDescriptors.task(for: task.id)).first
        )
        #expect(savedTask.thinkingNeeded == .high)
        #expect(savedTask.pressure == .none)
        let activityLogs = try context.fetch(FetchDescriptor<RoutinaDeviceActionLog>())
        #expect(
            activityLogs.contains {
                $0.action == .updated
                    && $0.entity == .task
                    && $0.entityID == task.id.uuidString
                    && $0.details == "Updated thinking needed"
            }
        )
    }

    @Test
    func noValueAndWrongFieldValuesDoNotSaveThinkingNeeded() async {
        let taskID = UUID()
        let task = RoutineTask(id: taskID, name: "Review contract")
        let display = MissingTaskDataFeature.State.Task(task: task)
        let store = TestStore(
            initialState: MissingTaskDataFeature.State(
                field: .thinkingNeeded,
                taskIDs: [taskID],
                currentTask: display,
                totalTaskCount: 1
            )
        ) {
            MissingTaskDataFeature(field: .thinkingNeeded)
        }

        await store.send(.valueSelected(taskID: taskID, value: .thinkingNeeded(.none)))
        await store.send(.valueSelected(taskID: taskID, value: .pressure(.high)))
    }

    @Test
    func iOSProcedureViewUsesTheSharedNoneValuedMetadataReducer() throws {
        let featureSource = try Self.sourceFile("SharedCore/Features/MissingData/MissingPressureDataFeature.swift")
        let viewSource = try Self.sourceFile("iOS/Screens/More/MissingPressureDataView.swift")
        let appViewSource = try Self.sourceFile("iOS/Screens/App/AppView.swift")

        #expect(featureSource.contains("case .thinkingNeeded"))
        #expect(featureSource.contains("task.thinkingNeededRawValue == missingRawValue"))
        #expect(featureSource.contains("typealias MissingThinkingNeededDataFeature"))
        #expect(viewSource.contains("let store: StoreOf<MissingTaskDataFeature>"))
        #expect(viewSource.contains("options: store.field.values"))
        #expect(viewSource.contains("store.send(.valueSelected"))
        #expect(!viewSource.contains("@Query"))
        #expect(!viewSource.contains("@Environment(\\.modelContext)"))
        #expect(!viewSource.contains("modelContext.save()"))
        #expect(!viewSource.contains("ScrollView"))
        #expect(appViewSource.contains("case taskReview"))
        #expect(appViewSource.contains("Section(\"Add missing task details\")"))
        #expect(appViewSource.contains("Add missing Thinking needed data"))
        #expect(appViewSource.contains("MissingTaskDataView(store: missingThinkingNeededDataStore)"))
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
