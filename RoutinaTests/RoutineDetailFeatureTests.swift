import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import Routina

@MainActor
struct RoutineDetailFeatureTests {
    @Test
    func setDeleteConfirmation_togglesAlertPresentation() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.setDeleteConfirmation(true)) {
            $0.isDeleteConfirmationPresented = true
        }

        await store.send(.setDeleteConfirmation(false)) {
            $0.isDeleteConfirmationPresented = false
        }
    }

    @Test
    func deleteRoutineConfirmed_removesTaskCancelsNotificationAndRequestsDismiss() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Stretch", interval: 3, lastDone: nil, emoji: "🤸")
        _ = makeLog(in: context, task: task, timestamp: Date())
        try context.save()

        let canceledIDs = LockIsolated<[String]>([])
        let initialState = RoutineDetailFeature.State(
            task: task,
            logs: [],
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: false,
            isEditSheetPresented: true,
            editRoutineName: "Stretch",
            editRoutineEmoji: "🤸",
            editFrequency: .day,
            editFrequencyValue: 3,
            isDeleteConfirmationPresented: true,
            shouldDismissAfterDelete: false
        )

        let store = TestStore(initialState: initialState) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { identifier in
                canceledIDs.withValue { $0.append(identifier) }
            }
        }

        let expectedIdentifier = task.id.uuidString

        await store.send(.deleteRoutineConfirmed) {
            $0.isDeleteConfirmationPresented = false
        }

        await store.receive(.routineDeleted) {
            $0.isEditSheetPresented = false
            $0.shouldDismissAfterDelete = true
        }

        let remainingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let remainingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(remainingTasks.isEmpty)
        #expect(remainingLogs.isEmpty)
        #expect(canceledIDs.value == [expectedIdentifier])
    }

    @Test
    func deleteDismissHandled_clearsDismissFlag() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Hydrate", interval: 1, lastDone: nil, emoji: "💧")

        let initialState = RoutineDetailFeature.State(
            task: task,
            logs: [],
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: false,
            isEditSheetPresented: false,
            editRoutineName: "",
            editRoutineEmoji: "✨",
            editFrequency: .day,
            editFrequencyValue: 1,
            isDeleteConfirmationPresented: false,
            shouldDismissAfterDelete: true
        )

        let store = TestStore(initialState: initialState) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.deleteDismissHandled) {
            $0.shouldDismissAfterDelete = false
        }
    }

    @Test
    func setEditSheetTrue_syncsEditFormFromTask_weekFrequency() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Stretch", interval: 14, lastDone: nil, emoji: "🤸", tags: ["Mobility", "Evening"])

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setEditSheet(true)) {
            $0.isEditSheetPresented = true
            $0.editRoutineName = "Stretch"
            $0.editRoutineEmoji = "🤸"
            $0.editRoutineTags = ["Mobility", "Evening"]
            $0.editFrequency = .week
            $0.editFrequencyValue = 2
        }
    }

    @Test
    func editAddTagTapped_parsesMultipleTagsAndDeduplicates() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let initialState = RoutineDetailFeature.State(task: task, editRoutineTags: ["Focus"], editTagDraft: "night, focus")

        let store = TestStore(initialState: initialState) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.editAddTagTapped) {
            $0.editRoutineTags = ["Focus", "night"]
            $0.editTagDraft = ""
        }
    }

    @Test
    func editRoutineEmojiChanged_sanitizesInputAndFallback() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let initialState = RoutineDetailFeature.State(
            task: task,
            logs: [],
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: false,
            isEditSheetPresented: false,
            editRoutineName: "",
            editRoutineEmoji: "✅",
            editFrequency: .day,
            editFrequencyValue: 1
        )

        let store = TestStore(initialState: initialState) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.editRoutineEmojiChanged("  🔥abc  ")) {
            $0.editRoutineEmoji = "🔥"
        }

        await store.send(.editRoutineEmojiChanged("   \n  "))
        #expect(store.state.editRoutineEmoji == "🔥")
    }

    @Test
    func editSaveTapped_withBlankName_doesNothing() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Original", interval: 10, lastDone: nil, emoji: "✨")

        let initialState = RoutineDetailFeature.State(
            task: task,
            logs: [],
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: false,
            isEditSheetPresented: true,
            editRoutineName: "   ",
            editRoutineEmoji: "🔥",
            editFrequency: .week,
            editFrequencyValue: 2
        )

        let store = TestStore(initialState: initialState) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.editSaveTapped)

        #expect(store.state.task.name == "Original")
        #expect(store.state.task.interval == 10)
        #expect(store.state.isEditSheetPresented)
    }

    @Test
    func editSaveTapped_persistsTagsIncludingPendingDraft() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 7, lastDone: nil, emoji: "📚", tags: ["Focus"])

        let store = TestStore(
            initialState: RoutineDetailFeature.State(
                task: task,
                logs: [],
                daysSinceLastRoutine: 0,
                overdueDays: 0,
                isDoneToday: false,
                isEditSheetPresented: true,
                editRoutineName: "  Deep Read  ",
                editRoutineEmoji: "🧠",
                editRoutineTags: ["Focus"],
                editTagDraft: "Night, focus",
                editFrequency: .week,
                editFrequencyValue: 2
            )
        ) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.editSaveTapped) {
            $0.editRoutineTags = ["Focus", "Night"]
            $0.editTagDraft = ""
            $0.isEditSheetPresented = false
        }

        await store.receive(.onAppear)
        await store.receive(.logsLoaded([])) {
            $0.logs = []
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = false
        }

        let persistedTaskID = task.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate<RoutineTask> { $0.id == persistedTaskID }
        )
        let persistedTask = try #require(context.fetch(descriptor).first)
        #expect(persistedTask.name == "Deep Read")
        #expect(persistedTask.emoji == "🧠")
        #expect(persistedTask.interval == 14)
        #expect(persistedTask.tags == ["Focus", "Night"])
    }

    @Test
    func editSaveTapped_rejectsDuplicateName_caseInsensitiveAndTrimmed() async throws {
        let context = makeInMemoryContext()
        _ = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        let editableTask = makeTask(in: context, name: "Workout", interval: 3, lastDone: nil, emoji: "💪")
        try context.save()

        let initialState = RoutineDetailFeature.State(
            task: editableTask,
            logs: [],
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: false,
            isEditSheetPresented: true,
            editRoutineName: "  read ",
            editRoutineEmoji: "🏋️",
            editFrequency: .week,
            editFrequencyValue: 1
        )

        let store = TestStore(initialState: initialState) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let names = tasks.compactMap(\.name)
        #expect(tasks.count == 2)
        #expect(names.contains("Read"))
        #expect(names.contains("Workout"))

        let unchanged = try #require(tasks.first(where: { $0.id == editableTask.id }))
        #expect(unchanged.interval == 3)
        #expect(unchanged.emoji == "💪")
    }

    @Test
    func logsLoaded_updatesDerivedStateFromLastDoneAndLogs() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let yesterday = makeDate("2026-02-24T08:00:00Z")
        let twoDaysAgo = makeDate("2026-02-23T08:00:00Z")

        let task = makeTask(in: context, name: "Meditate", interval: 1, lastDone: yesterday, emoji: "🧘")
        let logToday = makeLog(in: context, task: task, timestamp: now)
        let logOld = makeLog(in: context, task: task, timestamp: twoDaysAgo)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.logsLoaded([logToday])) {
            $0.logs = [logToday]
            $0.daysSinceLastRoutine = 1
            $0.overdueDays = 0
            $0.isDoneToday = true
        }

        await store.send(.logsLoaded([logOld])) {
            $0.logs = [logOld]
            $0.daysSinceLastRoutine = 1
            $0.overdueDays = 0
            $0.isDoneToday = false
        }
    }

    @Test
    func selectedDateChanged_updatesSelectedDate() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Journal", interval: 1, lastDone: nil, emoji: "📓")
        let selectedDate = makeDate("2026-02-22T08:00:00Z")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.selectedDateChanged(selectedDate)) {
            $0.selectedDate = calendar.startOfDay(for: selectedDate)
        }
    }

    @Test
    func onAppear_setsSelectedDateToTodayWhenUnset() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let task = makeTask(in: context, name: "Journal", interval: 1, lastDone: nil, emoji: "📓")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = false
        }

        await store.receive(.logsLoaded([])) {
            $0.logs = []
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = false
        }
    }

    @Test
    func markAsDone_setsImmediateStateAndPersistsLog() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let task = makeTask(in: context, name: "Hydrate", interval: 2, lastDone: nil, emoji: "💧")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.markAsDone) {
            $0.task.lastDone = now
            $0.isDoneToday = true
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
        }

        let taskID = task.id
        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let descriptor = FetchDescriptor<RoutineLog>(
                predicate: #Predicate<RoutineLog> { $0.taskID == taskID },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            $0.logs = (try? context.fetch(descriptor)) ?? []
            #expect($0.logs.count == 1)
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = true
        }

        let persistedLogs = (try? context.fetch(FetchDescriptor<RoutineLog>())) ?? []
        #expect(persistedLogs.count == 1)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func markAsDone_forSelectedPastDate_persistsLogWithoutRewindingLastDone() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let selectedDate = makeDate("2026-02-24T08:00:00Z")
        let todayLog = makeDate("2026-02-25T09:00:00Z")
        let task = makeTask(in: context, name: "Hydrate", interval: 2, lastDone: now, emoji: "💧")
        _ = makeLog(in: context, task: task, timestamp: todayLog)
        try context.save()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])
        let selectedDayStart = calendar.startOfDay(for: selectedDate)

        let initialState = RoutineDetailFeature.State(
            task: task,
            logs: [RoutineLog(timestamp: todayLog, taskID: task.id)],
            selectedDate: selectedDayStart,
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: true
        )

        let store = TestStore(initialState: initialState) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.markAsDone)

        let taskID = task.id
        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let logs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
            $0.logs = logs
            #expect(logs.count == 2)
            #expect(logs.contains { log in
                guard let timestamp = log.timestamp else { return false }
                return calendar.isDate(timestamp, inSameDayAs: selectedDayStart)
            })
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = true
        }

        let persistedTaskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { $0.id == persistedTaskID }
                )
            ).first
        )
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.lastDone == now)
        #expect(persistedLogs.count == 2)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func markAsDone_withExistingLogOnSelectedDate_doesNotCreateDuplicate() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let selectedDate = makeDate("2026-02-24T12:00:00Z")
        let task = makeTask(in: context, name: "Hydrate", interval: 2, lastDone: now, emoji: "💧")
        let existingLog = makeLog(in: context, task: task, timestamp: selectedDate)
        try context.save()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])
        let selectedDayStart = calendar.startOfDay(for: selectedDate)

        let initialState = RoutineDetailFeature.State(
            task: task,
            logs: [existingLog],
            selectedDate: selectedDayStart,
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: true
        )

        let store = TestStore(initialState: initialState) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.markAsDone)

        await store.receive(.logsLoaded([existingLog])) {
            $0.logs = [existingLog]
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = true
        }

        let persistedTaskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { $0.id == persistedTaskID }
                )
            ).first
        )
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.lastDone == now)
        #expect(persistedLogs.count == 1)
        #expect(scheduledIDs.value.isEmpty)
    }
}
