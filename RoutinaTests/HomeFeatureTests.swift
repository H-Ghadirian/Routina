import CloudKit
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
    func setAddRoutineSheet_seedsExistingNamesFromLoadedTasks() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let initialState = HomeFeature.State(
            routineTasks: [task],
            routineDisplays: [],
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
            $0.addRoutineState = AddRoutineFeature.State(existingRoutineNames: ["Read"])
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

        await store.send(.tasksLoadedSuccessfully([task], HomeFeature.DoneStats(totalCount: 3, countsByTaskID: [task.id: 3]))) {
            $0.routineTasks = [task]
            $0.doneStats = HomeFeature.DoneStats(totalCount: 3, countsByTaskID: [task.id: 3])
            $0.routineDisplays = [
                makeDisplay(taskID: task.id, name: "Unnamed task", emoji: "✨", interval: 1, lastDone: today, isDoneToday: true, doneCount: 3)
            ]
        }

        #expect(store.state.routineTasks.count == 1)
        #expect(store.state.routineDisplays.count == 1)
        #expect(store.state.doneStats.totalCount == 3)

        let display = try #require(store.state.routineDisplays.first)
        #expect(display.name == "Unnamed task")
        #expect(display.emoji == "✨")
        #expect(display.interval == 1)
        #expect(display.isDoneToday)
        #expect(display.doneCount == 3)
    }

    @Test
    func tasksLoadedSuccessfully_updatesOpenAddRoutineValidation() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let initialState = HomeFeature.State(
            routineTasks: [],
            routineDisplays: [],
            isAddRoutineSheetPresented: true,
            addRoutineState: AddRoutineFeature.State(routineName: "read")
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([task], HomeFeature.DoneStats())) {
            $0.routineTasks = [task]
            $0.routineDisplays = [
                makeDisplay(taskID: task.id, name: "Read", emoji: "📚", interval: 1, lastDone: nil, isDoneToday: false)
            ]
        }
        await store.receive(.addRoutineSheet(.existingRoutineNamesChanged(["Read"]))) {
            $0.addRoutineState?.existingRoutineNames = ["Read"]
            $0.addRoutineState?.nameValidationMessage = "A routine with this name already exists."
        }
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
                makeDisplay(taskID: task.id, name: "Walk", emoji: "🚶", interval: 2, lastDone: nil, isDoneToday: false)
            ]
        }

        #expect(store.state.routineTasks.count == 1)
        #expect(store.state.routineDisplays.count == 1)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func routineSavedSuccessfully_closesAddRoutineSheet() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Walk", interval: 2, lastDone: nil, emoji: "🚶")

        let initialState = HomeFeature.State(
            routineTasks: [],
            routineDisplays: [],
            isAddRoutineSheetPresented: true,
            addRoutineState: AddRoutineFeature.State(routineName: "Walk")
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.routineSavedSuccessfully(task)) {
            $0.routineTasks = [task]
            $0.routineDisplays = [
                makeDisplay(taskID: task.id, name: "Walk", emoji: "🚶", interval: 2, lastDone: nil, isDoneToday: false)
            ]
            $0.isAddRoutineSheetPresented = false
            $0.addRoutineState = nil
        }
    }

    @Test
    func deleteTasks_removesMatchingIDsFromState() async {
        let context = makeInMemoryContext()
        let task1 = makeTask(in: context, name: "A", interval: 1, lastDone: nil, emoji: "🅰️")
        let task2 = makeTask(in: context, name: "B", interval: 2, lastDone: nil, emoji: "🅱️")

        let initialState = HomeFeature.State(
            routineTasks: [task1, task2],
            routineDisplays: [
                makeDisplay(taskID: task1.id, name: "A", emoji: "🅰️", interval: 1, lastDone: nil, isDoneToday: false, doneCount: 2),
                makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
            ],
            doneStats: HomeFeature.DoneStats(totalCount: 3, countsByTaskID: [task1.id: 2, task2.id: 1]),
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
                makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
            ]
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task2.id: 1])
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
                makeDisplay(taskID: task1.id, name: "A", emoji: "🅰️", interval: 1, lastDone: nil, isDoneToday: false, doneCount: 1),
                makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
            ],
            doneStats: HomeFeature.DoneStats(totalCount: 2, countsByTaskID: [task1.id: 1, task2.id: 1]),
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
                makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
            ]
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task2.id: 1])
        }

        let remainingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(remainingLogs.count == 1)
        #expect(remainingLogs.first?.taskID == task2.id)
    }

    @Test
    func markTaskDone_updatesStateAndPersistsLog() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 3, lastDone: nil, emoji: "📚")
        try context.save()

        let now = makeDate("2026-03-14T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])

        let initialState = HomeFeature.State(
            routineTasks: [task],
            routineDisplays: [
                makeDisplay(taskID: task.id, name: "Read", emoji: "📚", interval: 3, lastDone: nil, isDoneToday: false)
            ],
            doneStats: HomeFeature.DoneStats(),
            isAddRoutineSheetPresented: false,
            addRoutineState: nil
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
            $0.calendar = calendar
            $0.date.now = now
        }

        await store.send(.markTaskDone(task.id)) {
            $0.routineTasks[0].lastDone = now
            $0.routineDisplays[0].lastDone = now
            $0.routineDisplays[0].isDoneToday = true
            $0.routineDisplays[0].doneCount = 1
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task.id: 1])
        }

        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(savedTask.lastDone == now)
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(scheduledIDs.value == [task.id.uuidString])
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
            guard case let .tasksLoadedSuccessfully(tasks, doneStats) = action else { return false }
            #expect(tasks.count == 1)
            #expect(tasks.first?.id == first.id)
            #expect(doneStats.totalCount == 0)
            return true
        } assert: {
            $0.routineTasks = [first]
            $0.routineDisplays = [
                makeDisplay(taskID: first.id, name: "Routine A", emoji: "🅰️", interval: 1, lastDone: nil, isDoneToday: false)
            ]
        }

        let remainingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let remainingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(remainingTasks.count == 1)
        #expect(remainingTasks.first?.id == first.id)
        #expect(remainingLogs.isEmpty)
    }

    @Test
    func onAppear_backfillsMissingLogFromLastDone() async throws {
        let context = makeInMemoryContext()
        let lastDone = makeDate("2026-03-14T10:00:00Z")
        let task = makeTask(in: context, name: "Shave Beard", interval: 4, lastDone: lastDone, emoji: "💪")
        try context.save()

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.onAppear)
        await store.receive { action in
            guard case let .tasksLoadedSuccessfully(tasks, doneStats) = action else { return false }
            #expect(tasks.count == 1)
            #expect(tasks.first?.id == task.id)
            #expect(doneStats.totalCount == 1)
            #expect(doneStats.countsByTaskID[task.id] == 1)
            return true
        } assert: {
            $0.routineTasks = [task]
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task.id: 1])
            $0.routineDisplays = [
                makeDisplay(taskID: task.id, name: "Shave Beard", emoji: "💪", interval: 4, lastDone: lastDone, isDoneToday: Calendar.current.isDateInToday(lastDone), doneCount: 1)
            ]
        }

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == lastDone)
    }

    @Test
    func cloudKitMerge_skipsLogicalDuplicateLogsFromRefresh() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        let timestamp = makeDate("2026-03-15T08:00:00Z")
        _ = makeLog(in: context, task: task, timestamp: timestamp)
        try context.save()

        let cloudLog = CKRecord(
            recordType: "RoutineLog",
            recordID: CKRecord.ID(recordName: UUID().uuidString)
        )
        cloudLog["taskID"] = task.id.uuidString as CKRecordValue
        cloudLog["timestamp"] = timestamp as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [cloudLog], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == timestamp)
    }

    @Test
    func cloudKitMerge_removesExistingDuplicateLogsDuringRefresh() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Walk", interval: 1, lastDone: nil, emoji: "🚶")
        let timestamp = makeDate("2026-03-15T09:30:00Z")
        _ = makeLog(in: context, task: task, timestamp: timestamp)
        _ = makeLog(in: context, task: task, timestamp: timestamp)
        try context.save()

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == timestamp)
    }

    @Test
    func cloudKitMerge_sameNamedTaskRemapsLogsToExistingLocalTask() throws {
        let context = makeInMemoryContext()
        let localTask = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        try context.save()

        let remoteTaskID = UUID()
        let timestamp = makeDate("2026-03-14T08:00:00Z")

        let remoteLog = CKRecord(
            recordType: "RoutineLog",
            recordID: CKRecord.ID(recordName: UUID().uuidString)
        )
        remoteLog["taskID"] = remoteTaskID.uuidString as CKRecordValue
        remoteLog["timestamp"] = timestamp as CKRecordValue

        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: remoteTaskID.uuidString)
        )
        remoteTask["name"] = "Read" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: 1)
        remoteTask["lastDone"] = timestamp as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [remoteLog, remoteTask], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == localTask.id)

        let refreshedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.id == localTask.id
                    }
                )
            ).first
        )
        #expect(refreshedTask.lastDone == timestamp)

        let detailLogs = HomeFeature.detailLogs(taskID: localTask.id, context: context)
        #expect(detailLogs.count == 1)
        #expect(detailLogs.first?.taskID == localTask.id)
        #expect(detailLogs.first?.timestamp == timestamp)
    }
}

private func makeDisplay(
    taskID: UUID,
    name: String,
    emoji: String,
    interval: Int,
    lastDone: Date?,
    isDoneToday: Bool,
    doneCount: Int = 0
) -> HomeFeature.RoutineDisplay {
    HomeFeature.RoutineDisplay(
        taskID: taskID,
        name: name,
        emoji: emoji,
        interval: interval,
        lastDone: lastDone,
        isDoneToday: isDoneToday,
        doneCount: doneCount
    )
}
