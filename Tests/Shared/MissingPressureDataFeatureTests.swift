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
struct MissingPressureDataFeatureTests {
    @Test
    func onAppear_loadsRepeatingAndUnfinishedOneOffTasksWithMissingPressureInTitleOrder() async throws {
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
        let completedTask = makeTask(
            in: context,
            name: "Already categorized",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        completedTask.pressure = .high
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
        try context.save()

        let store = TestStore(initialState: MissingPressureDataFeature.State()) {
            MissingPressureDataFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.calendar = Calendar(identifier: .gregorian)
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(
            .tasksLoaded(
                taskIDs: [firstTask.id, completedRepeatingTask.id, openOneOffTask.id, laterTask.id],
                currentTask: MissingPressureDataFeature.State.Task(task: firstTask)
            )
        ) {
            $0.taskIDs = [firstTask.id, completedRepeatingTask.id, openOneOffTask.id, laterTask.id]
            $0.currentTask = MissingPressureDataFeature.State.Task(task: firstTask)
            $0.totalTaskCount = 4
            $0.hasLoadedTasks = true
            $0.isLoading = false
        }

        #expect(
            store.state.taskIDs
                == [firstTask.id, completedRepeatingTask.id, openOneOffTask.id, laterTask.id]
        )
        #expect(store.state.currentTask?.title == "Buy coffee")
        #expect(!store.state.taskIDs.contains(completedOneOffTask.id))
        #expect(!store.state.taskIDs.contains(canceledOneOffTask.id))
        #expect(store.state.totalTaskCount == 4)
        #expect(store.state.currentTaskNumber == 1)
    }

    @Test
    func onAppear_loadsCardContextForTagsPathAndSchedulingLabels() async throws {
        let context = makeInMemoryContext()
        let referenceDate = makeDate("2026-08-05T12:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let rootSection = HomeCustomTaskSection(title: "Personal")
        let childSection = HomeCustomTaskSection(
            parentSectionID: rootSection.id,
            title: "Errands"
        )
        let task = makeTask(
            in: context,
            name: "Buy coffee",
            interval: 1,
            lastDone: nil,
            emoji: nil,
            tags: ["Errands", "Morning", "Home", "Quick"],
            scheduleMode: .oneOff
        )
        task.customTaskSectionID = childSection.id
        task.plannedDate = referenceDate
        task.deadline = calendar.date(byAdding: .day, value: 1, to: referenceDate)
        task.todoStateRawValue = TodoState.blocked.rawValue
        try context.save()

        let expectedTask = MissingPressureDataFeature.State.Task(
            task: task,
            customTaskSections: [rootSection, childSection],
            referenceDate: referenceDate,
            calendar: calendar
        )
        let store = TestStore(initialState: MissingPressureDataFeature.State()) {
            MissingPressureDataFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.customTaskSections = { [rootSection, childSection] }
            $0.date.now = referenceDate
            $0.calendar = calendar
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(.tasksLoaded(taskIDs: [task.id], currentTask: expectedTask)) {
            $0.taskIDs = [task.id]
            $0.currentTask = expectedTask
            $0.totalTaskCount = 1
            $0.hasLoadedTasks = true
            $0.isLoading = false
        }

        let card = try #require(store.state.currentTask)
        #expect(card.tags == ["Errands", "Morning", "Home"])
        #expect(card.additionalTagCount == 1)
        #expect(card.path == ["Personal", "Errands"])
        #expect(card.labels.map(\.title) == ["Planned today", "Due tomorrow", "Blocked"])
    }

    @Test
    func selectingPressure_persistsTheCurrentTaskAndAdvancesTheProcedure() async throws {
        let context = makeInMemoryContext()
        let firstTask = makeTask(
            in: context,
            name: "Book dentist",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let secondTask = makeTask(
            in: context,
            name: "File receipts",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let firstDisplay = MissingPressureDataFeature.State.Task(task: firstTask)
        let secondDisplay = MissingPressureDataFeature.State.Task(task: secondTask)

        let store = TestStore(
            initialState: MissingPressureDataFeature.State(
                taskIDs: [firstTask.id, secondTask.id],
                currentTask: firstDisplay,
                totalTaskCount: 2
            )
        ) {
            MissingPressureDataFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.calendar = Calendar(identifier: .gregorian)
        }

        await store.send(.valueSelected(taskID: firstTask.id, value: .pressure(.high))) {
            $0.isSaving = true
        }
        await store.receive(.valueSaved(taskID: firstTask.id)) {
            $0.taskIDs = [secondTask.id]
            $0.currentTask = nil
            $0.completedTaskCount = 1
            $0.currentTaskIndex = 1
        }
        await store.receive(.currentTaskLoaded(taskID: secondTask.id, task: secondDisplay)) {
            $0.currentTask = secondDisplay
            $0.isSaving = false
        }

        let persistedTask = try #require(
            try context.fetch(TaskDetailFetchDescriptors.task(for: firstTask.id)).first
        )
        #expect(persistedTask.pressure == .high)
        #expect(persistedTask.pressureUpdatedAt != nil)
        let activityLogs = try context.fetch(FetchDescriptor<RoutinaDeviceActionLog>())
        #expect(
            activityLogs.contains {
                $0.action == .updated
                    && $0.entity == .task
                    && $0.entityID == firstTask.id.uuidString
                    && $0.details == "Updated pressure"
            }
        )
        #expect(store.state.currentTask?.id == secondTask.id)
        #expect(store.state.currentTaskNumber == 2)
        #expect(store.state.progressValue == 0.5)
    }

    @Test
    func selectingNone_doesNotEndTheProcedureOrPersistAValue() async {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Plan trip",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let display = MissingPressureDataFeature.State.Task(task: task)
        let store = TestStore(
            initialState: MissingPressureDataFeature.State(
                taskIDs: [task.id],
                currentTask: display,
                totalTaskCount: 1
            )
        ) {
            MissingPressureDataFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.calendar = Calendar(identifier: .gregorian)
        }

        await store.send(.valueSelected(taskID: task.id, value: .pressure(.none)))

        #expect(task.pressure == .none)
        #expect(store.state.taskIDs == [task.id])
        #expect(store.state.currentTask == display)
        #expect(!store.state.isSaving)
    }

    @Test
    func skippingCurrentTask_keepsItMissingAndMovesToTheNextTask() async {
        let context = makeInMemoryContext()
        let firstTask = makeTask(
            in: context,
            name: "Book dentist",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let secondTask = makeTask(
            in: context,
            name: "File receipts",
            interval: 1,
            lastDone: nil,
            emoji: nil
        )
        let firstDisplay = MissingPressureDataFeature.State.Task(task: firstTask)
        let secondDisplay = MissingPressureDataFeature.State.Task(task: secondTask)
        let store = TestStore(
            initialState: MissingPressureDataFeature.State(
                taskIDs: [firstTask.id, secondTask.id],
                currentTask: firstDisplay,
                totalTaskCount: 2
            )
        ) {
            MissingPressureDataFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.calendar = Calendar(identifier: .gregorian)
        }

        await store.send(.skipTask(taskID: firstTask.id)) {
            $0.taskIDs = [secondTask.id, firstTask.id]
            $0.currentTaskIndex = 1
            $0.isSaving = true
        }
        await store.receive(.currentTaskLoaded(taskID: secondTask.id, task: secondDisplay)) {
            $0.currentTask = secondDisplay
            $0.isSaving = false
        }

        #expect(firstTask.pressure == .none)
        #expect(store.state.currentTask?.id == secondTask.id)
        #expect(store.state.currentTaskNumber == 2)
        #expect(store.state.completedTaskCount == 0)
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
        let display = MissingPressureDataFeature.State.Task(task: task)
        let store = TestStore(
            initialState: MissingPressureDataFeature.State(
                taskIDs: [task.id],
                currentTask: display,
                totalTaskCount: 1
            )
        ) {
            MissingPressureDataFeature()
        }

        await store.send(.taskDetailsTapped(taskID: task.id))
        await store.receive(.delegate(.taskDetailsRequested(task.id)))
    }

    @Test
    func iOSProcedureViewKeepsSwiftDataWorkInTheReducer() throws {
        let source = try Self.sourceFile("iOS/Screens/More/MissingPressureDataView.swift")

        #expect(source.contains("let store: StoreOf<MissingTaskDataFeature>"))
        #expect(source.contains("store.send(.valueSelected"))
        #expect(source.contains("options: store.field.values"))
        #expect(source.contains("store.send(.skipTask"))
        #expect(source.contains("store.send(.taskDetailsTapped"))
        #expect(source.contains("taskContext(task)"))
        #expect(source.contains("GuidedReviewProgressHeader"))
        #expect(source.contains("navigationTitleClearance"))
        #expect(source.contains(".padding(.top, navigationTitleClearance)"))
        #expect(!source.contains("@Query"))
        #expect(!source.contains("@Environment(\\.modelContext)"))
        #expect(!source.contains("modelContext.save()"))
        #expect(!source.contains("ScrollView"))
        #expect(!source.contains("DragGesture"))
    }

    @Test
    func guidedProcedureLoadersKeepOnlyTheVisibleCardPresentationInState() throws {
        let pressureSource = try Self.sourceFile("SharedCore/Features/MissingData/MissingPressureDataFeature.swift")
        let metadataSource = try Self.sourceFile("SharedCore/Features/MissingData/MissingTaskMetadataFeature.swift")

        for source in [pressureSource, metadataSource] {
            #expect(source.contains("var taskIDs: [UUID] = []"))
            #expect(source.contains("var currentTask: Task?"))
            #expect(source.contains("let currentTask = tasks.first.map"))
            #expect(!source.contains(".map { task in\n                    State.Task("))
        }
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
