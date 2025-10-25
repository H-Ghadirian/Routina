import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import Routina

@MainActor
struct HomeFeatureTests {
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
            $0.addRoutineState = AddRoutineFeature.State(existingRoutineNames: [])
        }

        await store.send(.setAddRoutineSheet(false)) {
            $0.isAddRoutineSheetPresented = false
            $0.addRoutineState = nil
        }
    }

    @Test
    func tasksLoadedSuccessfully_mapsDisplayWithFallbacksAndDoneToday() async throws {
        let context = makeInMemoryContext()
        let today = Date()

        let task = makeTask(
            in: context,
            name: nil,
            interval: 0,
            lastDone: today,
            emoji: ""
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([task])) {
            $0.routineTasks = [task]
            $0.routineDisplays = [
                HomeFeature.RoutineDisplay(
                    taskID: task.id,
                    name: "Unnamed task",
                    emoji: "✨",
                    interval: 1,
                    lastDone: today,
                    isDoneToday: true
                )
            ]
        }

        #expect(store.state.routineTasks.count == 1)
        #expect(store.state.routineDisplays.count == 1)

        let display = try #require(store.state.routineDisplays.first)
        #expect(display.name == "Unnamed task")
        #expect(display.emoji == "✨")
        #expect(display.interval == 1)
        #expect(display.isDoneToday)
    }

    @Test
    func addRoutineSheetCancel_closesSheet() async {
        let context = makeInMemoryContext()
        let initialState = HomeFeature.State(
            routineTasks: [],
            routineDisplays: [],
            isAddRoutineSheetPresented: true,
            addRoutineState: AddRoutineFeature.State(existingRoutineNames: [])
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.addRoutineSheet(.delegate(.didCancel))) {
            $0.isAddRoutineSheetPresented = false
            $0.addRoutineState = nil
        }
    }

    @Test
    func routineSavedSuccessfully_appendsTaskAndSchedulesNotification() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Walk", interval: 2, lastDone: nil, emoji: "🚶")
        let scheduledIDs = LockIsolated<[String]>([])

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.routineSavedSuccessfully(task)) {
            $0.routineTasks = [task]
            $0.routineDisplays = [
                HomeFeature.RoutineDisplay(
                    taskID: task.id,
                    name: "Walk",
                    emoji: "🚶",
                    interval: 2,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }

        #expect(store.state.routineTasks.count == 1)
        #expect(store.state.routineDisplays.count == 1)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func deleteTasks_removesMatchingIDsFromState() async {
        let context = makeInMemoryContext()
        let task1 = makeTask(in: context, name: "A", interval: 1, lastDone: nil, emoji: "🅰️")
        let task2 = makeTask(in: context, name: "B", interval: 2, lastDone: nil, emoji: "🅱️")

        let initialState = HomeFeature.State(
            routineTasks: [task1, task2],
            routineDisplays: [
                HomeFeature.RoutineDisplay(
                    taskID: task1.id,
                    name: "A",
                    emoji: "🅰️",
                    interval: 1,
                    lastDone: nil,
                    isDoneToday: false
                ),
                HomeFeature.RoutineDisplay(
                    taskID: task2.id,
                    name: "B",
                    emoji: "🅱️",
                    interval: 2,
                    lastDone: nil,
                    isDoneToday: false
                )
            ],
            isAddRoutineSheetPresented: false,
            addRoutineState: nil
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.deleteTasks([task1.id])) {
            $0.routineTasks = [task2]
            $0.routineDisplays = [
                HomeFeature.RoutineDisplay(
                    taskID: task2.id,
                    name: "B",
                    emoji: "🅱️",
                    interval: 2,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }
    }

    @Test
    func deleteTasks_removesAssociatedLogsFromPersistence() async throws {
        let context = makeInMemoryContext()
        let task1 = makeTask(in: context, name: "A", interval: 1, lastDone: nil, emoji: "🅰️")
        let task2 = makeTask(in: context, name: "B", interval: 2, lastDone: nil, emoji: "🅱️")
        _ = makeLog(in: context, task: task1, timestamp: Date())
        _ = makeLog(in: context, task: task2, timestamp: Date())
        try context.save()

        let initialState = HomeFeature.State(
            routineTasks: [task1, task2],
            routineDisplays: [
                HomeFeature.RoutineDisplay(
                    taskID: task1.id,
                    name: "A",
                    emoji: "🅰️",
                    interval: 1,
                    lastDone: nil,
                    isDoneToday: false
                ),
                HomeFeature.RoutineDisplay(
                    taskID: task2.id,
                    name: "B",
                    emoji: "🅱️",
                    interval: 2,
                    lastDone: nil,
                    isDoneToday: false
                )
            ],
            isAddRoutineSheetPresented: false,
            addRoutineState: nil
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.deleteTasks([task1.id])) {
            $0.routineTasks = [task2]
            $0.routineDisplays = [
                HomeFeature.RoutineDisplay(
                    taskID: task2.id,
                    name: "B",
                    emoji: "🅱️",
                    interval: 2,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }

        let remainingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(remainingLogs.count == 1)
        #expect(remainingLogs.first?.taskID == task2.id)
    }

    @Test
    func detailLogs_returnsPersistedLogsForSelectedTaskSortedNewestFirst() throws {
        let context = makeInMemoryContext()
        let selectedTask = makeTask(in: context, name: "Selected", interval: 1, lastDone: nil, emoji: "✅")
        let otherTask = makeTask(in: context, name: "Other", interval: 1, lastDone: nil, emoji: "❌")
        let older = makeDate("2026-02-27T08:00:00Z")
        let newer = makeDate("2026-02-28T08:00:00Z")

        let olderLog = makeLog(in: context, task: selectedTask, timestamp: older)
        let newerLog = makeLog(in: context, task: selectedTask, timestamp: newer)
        _ = makeLog(in: context, task: otherTask, timestamp: newer)
        try context.save()

        let logs = HomeFeature.detailLogs(taskID: selectedTask.id, context: context)

        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.taskID == selectedTask.id })
        #expect(logs.first?.id == newerLog.id)
        #expect(logs.last?.id == olderLog.id)
    }

    @Test
    func addRoutine_rejectsDuplicateName_caseInsensitiveAndTrimmed() async throws {
        let context = makeInMemoryContext()
        _ = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        try context.save()

        let initialState = HomeFeature.State(
            routineTasks: [],
            routineDisplays: [],
            isAddRoutineSheetPresented: true,
            addRoutineState: AddRoutineFeature.State(existingRoutineNames: [])
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.addRoutineSheet(.delegate(.didSave("  read  ", 7, "🔥"))))
        await store.receive(.routineSaveFailed)

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.name == "Read")
        #expect(store.state.isAddRoutineSheetPresented)
    }

    @Test
    func onAppear_enforcesUniqueNamesByRemovingDuplicates() async throws {
        let context = makeInMemoryContext()
        let first = makeTask(in: context, name: "Routine A", interval: 1, lastDone: nil, emoji: "🅰️")
        let duplicate = makeTask(in: context, name: "  routine a  ", interval: 3, lastDone: nil, emoji: "♻️")
        _ = makeLog(in: context, task: duplicate, timestamp: Date())
        try context.save()

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.onAppear)
        await store.receive { action in
            guard case let .tasksLoadedSuccessfully(tasks) = action else { return false }
            #expect(tasks.count == 1)
            #expect(tasks.first?.id == first.id)
            return true
        } assert: {
            $0.routineTasks = [first]
            $0.routineDisplays = [
                HomeFeature.RoutineDisplay(
                    taskID: first.id,
                    name: "Routine A",
                    emoji: "🅰️",
                    interval: 1,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }

        let remainingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let remainingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(remainingTasks.count == 1)
        #expect(remainingTasks.first?.id == first.id)
        #expect(remainingLogs.isEmpty)
    }
}
