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
struct MissingEstimatedDurationDataFeatureTests {
    @Test
    func onAppear_loadsOnlyTasksWithoutAnEstimateInTitleOrder() async throws {
        let context = makeInMemoryContext()
        let laterTask = makeTask(in: context, name: "Write proposal", interval: 1, lastDone: nil, emoji: nil)
        let firstTask = makeTask(in: context, name: "Call lawyer", interval: 1, lastDone: nil, emoji: nil)
        let estimatedTask = makeTask(in: context, name: "Already estimated", interval: 1, lastDone: nil, emoji: nil)
        estimatedTask.estimatedDurationMinutes = 30
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
            name: "Archived estimate task",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            scheduleMode: .oneOff
        )
        archivedTask.pausedAt = Date(timeIntervalSince1970: 1)
        try context.save()

        let store = TestStore(
            initialState: MissingTaskDataFeature.State(field: .estimatedDuration)
        ) {
            MissingTaskDataFeature(field: .estimatedDuration)
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

        #expect(!store.state.taskIDs.contains(estimatedTask.id))
        #expect(!store.state.taskIDs.contains(completedOneOffTask.id))
        #expect(!store.state.taskIDs.contains(canceledOneOffTask.id))
        #expect(!store.state.taskIDs.contains(archivedTask.id))
    }

    @Test
    func selectingEstimate_requiresConfirmationBeforeItSavesAndAdvances() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Prepare tax documents", interval: 1, lastDone: nil, emoji: nil)
        task.pressure = .high
        task.thinkingNeeded = .medium
        let display = MissingTaskDataFeature.State.Task(task: task)
        let store = TestStore(
            initialState: MissingTaskDataFeature.State(
                field: .estimatedDuration,
                taskIDs: [task.id],
                currentTask: display,
                totalTaskCount: 1
            )
        ) {
            MissingTaskDataFeature(field: .estimatedDuration)
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.valueSelected(taskID: task.id, value: .estimatedDuration(60))) {
            $0.timeEstimateSelection = .preset(60)
        }
        #expect(try #require(store.state.selectedTimeEstimateMinutes) == 60)
        #expect(try #require(store.state.selectedTimeEstimateTitle) == "1 hour")

        let taskBeforeSaving = try #require(
            try context.fetch(TaskDetailFetchDescriptors.task(for: task.id)).first
        )
        #expect(taskBeforeSaving.estimatedDurationMinutes == nil)

        await store.send(.saveSelectedTimeEstimate(taskID: task.id)) {
            $0.isSaving = true
        }
        await store.receive(.valueSaved(taskID: task.id)) {
            $0.taskIDs = []
            $0.currentTask = nil
            $0.completedTaskCount = 1
            $0.currentTaskIndex = 0
            $0.isSaving = false
            $0.timeEstimateSelection = nil
        }

        let savedTask = try #require(
            try context.fetch(TaskDetailFetchDescriptors.task(for: task.id)).first
        )
        #expect(savedTask.estimatedDurationMinutes == 60)
        #expect(savedTask.actualDurationMinutes == nil)
        #expect(savedTask.pressure == .high)
        #expect(savedTask.thinkingNeeded == .medium)
        let activityLogs = try context.fetch(FetchDescriptor<RoutinaDeviceActionLog>())
        #expect(
            activityLogs.contains {
                $0.action == .updated
                    && $0.entity == .task
                    && $0.entityID == task.id.uuidString
                    && $0.details == "Updated time estimate"
            }
        )
    }

    @Test
    func missingAndWrongFieldValuesDoNotSaveAnEstimate() async {
        let taskID = UUID()
        let task = RoutineTask(id: taskID, name: "Review contract")
        let display = MissingTaskDataFeature.State.Task(task: task)
        let store = TestStore(
            initialState: MissingTaskDataFeature.State(
                field: .estimatedDuration,
                taskIDs: [taskID],
                currentTask: display,
                totalTaskCount: 1
            )
        ) {
            MissingTaskDataFeature(field: .estimatedDuration)
        }

        await store.send(.valueSelected(taskID: taskID, value: .estimatedDuration(0)))
        await store.send(.valueSelected(taskID: taskID, value: .pressure(.high)))
        await store.send(.saveSelectedTimeEstimate(taskID: taskID))
    }

    @Test
    func customTimeIsVisibleAsAnEditableDraftBeforeSaving() async {
        let taskID = UUID()
        let task = RoutineTask(id: taskID, name: "Review contract")
        let display = MissingTaskDataFeature.State.Task(task: task)
        let store = TestStore(
            initialState: MissingTaskDataFeature.State(
                field: .estimatedDuration,
                taskIDs: [taskID],
                currentTask: display,
                totalTaskCount: 1
            )
        ) {
            MissingTaskDataFeature(field: .estimatedDuration)
        }

        await store.send(.customTimeEstimateChanged(hours: "1", minutes: "25")) {
            $0.timeEstimateSelection = .custom(hours: "1", minutes: "25")
        }
        #expect(store.state.selectedTimeEstimateMinutes == 85)
        #expect(store.state.selectedTimeEstimateTitle == "1h 25m")

        await store.send(.customTimeEstimateChanged(hours: "", minutes: "3")) {
            $0.timeEstimateSelection = .custom(hours: "", minutes: "3")
        }
        #expect(store.state.selectedTimeEstimateMinutes == nil)
        #expect(store.state.timeEstimateValidationMessage != nil)
    }

    @Test
    func durationProcedureUsesDirectTwoRowPresetsAndReducerOwnedPersistence() throws {
        let featureSource = try Self.sourceFile("SharedCore/Features/MissingData/MissingPressureDataFeature.swift")
        let viewSource = try Self.sourceFile("iOS/Screens/More/MissingPressureDataView.swift")
        let appViewSource = try Self.sourceFile("iOS/Screens/App/AppView.swift")

        #expect(featureSource.contains("case estimatedDuration"))
        #expect(featureSource.contains("hasMissingValue = task.estimatedDurationMinutes == nil"))
        #expect(featureSource.contains("fetch(taskDescriptor()).filter(isEligible)"))
        #expect(featureSource.contains("[15, 30, 60, 120, 240, 480, 1_200]"))
        #expect(featureSource.contains("typealias MissingEstimatedDurationDataFeature"))
        #expect(featureSource.contains("case saveSelectedTimeEstimate"))
        #expect(featureSource.contains("case customTimeEstimateChanged"))
        #expect(viewSource.contains("maximumSegmentsPerRow: store.field.maximumSegmentsPerRow"))
        #expect(viewSource.contains("timeEstimateChoices"))
        #expect(viewSource.contains("Or enter a custom time"))
        #expect(viewSource.contains("saveSelectedTimeEstimate"))
        #expect(!viewSource.contains("@Query"))
        #expect(!viewSource.contains("@Environment(\\.modelContext)"))
        #expect(!viewSource.contains("modelContext.save()"))
        #expect(!viewSource.contains("ScrollView"))
        #expect(appViewSource.contains("case missingEstimatedDurationData"))
        #expect(appViewSource.contains("Add missing time estimates"))
        #expect(appViewSource.contains("MissingTaskDataView(store: missingEstimatedDurationDataStore)"))
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
