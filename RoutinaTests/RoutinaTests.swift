import ComposableArchitecture
import CoreData
import Foundation
import Testing
#if canImport(RoutinaProd)
@testable @preconcurrency import RoutinaProd
#elseif canImport(Routina)
@testable @preconcurrency import Routina
#else
#error("Unable to import app module for tests")
#endif

@MainActor
struct AddRoutineFeatureTests {
    @Test
    func frequencyMetadata_isConsistent() {
        #expect(AddRoutineFeature.Frequency.day.daysMultiplier == 1)
        #expect(AddRoutineFeature.Frequency.week.daysMultiplier == 7)
        #expect(AddRoutineFeature.Frequency.month.daysMultiplier == 30)

        #expect(AddRoutineFeature.Frequency.day.singularLabel == "day")
        #expect(AddRoutineFeature.Frequency.week.singularLabel == "week")
        #expect(AddRoutineFeature.Frequency.month.singularLabel == "month")
    }

    @Test
    func emojiSanitization_keepsOnlyFirstCharacter() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(onSave: { _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineEmojiChanged("  🔥🎯  ")) {
            $0.routineEmoji = "🔥"
        }
    }

    @Test
    func emojiSanitization_usesFallbackWhenEmptyInput() async {
        let initialState = AddRoutineFeature.State(routineName: "", routineEmoji: "✅", frequency: .day, frequencyValue: 1)
        let store = TestStore(initialState: initialState) {
            AddRoutineFeature(onSave: { _, _, _ in .none }, onCancel: { .none })
        }

        await store.send(.routineEmojiChanged("   \n  "))
        #expect(store.state.routineEmoji == "✅")
    }

    @Test
    func saveTapped_sendsDelegateWithFrequencyInDays() async {
        let store = TestStore(
            initialState: AddRoutineFeature.State(
                routineName: "Read",
                routineEmoji: "📚",
                frequency: .week,
                frequencyValue: 3
            )
        ) {
            AddRoutineFeature(
                onSave: { name, frequencyInDays, emoji in
                    .send(.delegate(.didSave(name, frequencyInDays, emoji)))
                },
                onCancel: { .none }
            )
        }

        await store.send(.saveTapped)
        await store.receive(.delegate(.didSave("Read", 21, "📚")))
    }

    @Test
    func cancelTapped_sendsCancelDelegate() async {
        let store = TestStore(initialState: AddRoutineFeature.State()) {
            AddRoutineFeature(
                onSave: { _, _, _ in .none },
                onCancel: { .send(.delegate(.didCancel)) }
            )
        }

        await store.send(.cancelTapped)
        await store.receive(.delegate(.didCancel))
    }
}

@MainActor
struct HomeFeatureTests {
    @Test
    func setAddRoutineSheet_togglesPresentationAndChildState() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.managedObjectContext = context
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setAddRoutineSheet(true)) {
            $0.isAddRoutineSheetPresented = true
            $0.addRoutineState = AddRoutineFeature.State()
        }

        await store.send(.setAddRoutineSheet(false)) {
            $0.isAddRoutineSheetPresented = false
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
            lastDone: nil,
            emoji: ""
        )
        _ = makeLog(in: context, task: task, timestamp: today)

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.managedObjectContext = context
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([task])) {
            $0.routineTasks = [task]
            $0.routineDisplays = [
                HomeFeature.RoutineDisplay(
                    id: task.objectID.uriRepresentation().absoluteString,
                    objectID: task.objectID,
                    name: "Unnamed task",
                    emoji: "✨",
                    interval: 1,
                    lastDone: nil,
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
            addRoutineState: AddRoutineFeature.State()
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.managedObjectContext = context
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.addRoutineSheet(.delegate(.didCancel))) {
            $0.isAddRoutineSheetPresented = false
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
            $0.managedObjectContext = context
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.routineSavedSuccessfully(task)) {
            $0.routineTasks = [task]
            $0.routineDisplays = [
                HomeFeature.RoutineDisplay(
                    id: task.objectID.uriRepresentation().absoluteString,
                    objectID: task.objectID,
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
        #expect(scheduledIDs.value == [task.objectID.uriRepresentation().absoluteString])
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
                    id: task1.objectID.uriRepresentation().absoluteString,
                    objectID: task1.objectID,
                    name: "A",
                    emoji: "🅰️",
                    interval: 1,
                    lastDone: nil,
                    isDoneToday: false
                ),
                HomeFeature.RoutineDisplay(
                    id: task2.objectID.uriRepresentation().absoluteString,
                    objectID: task2.objectID,
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
            $0.managedObjectContext = context
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.deleteTasks([task1.objectID])) {
            $0.routineTasks = [task2]
            $0.routineDisplays = [
                HomeFeature.RoutineDisplay(
                    id: task2.objectID.uriRepresentation().absoluteString,
                    objectID: task2.objectID,
                    name: "B",
                    emoji: "🅱️",
                    interval: 2,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }
    }
}

@MainActor
struct RoutineDetailFeatureTests {
    @Test
    func setDeleteConfirmation_togglesAlertPresentation() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.managedObjectContext = context
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
            $0.managedObjectContext = context
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { identifier in
                canceledIDs.withValue { $0.append(identifier) }
            }
        }

        let expectedIdentifier = task.objectID.uriRepresentation().absoluteString

        await store.send(.deleteRoutineConfirmed) {
            $0.isDeleteConfirmationPresented = false
        }

        await store.receive(.routineDeleted) {
            $0.isEditSheetPresented = false
            $0.shouldDismissAfterDelete = true
        }

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "RoutineTask")
        #expect((try? context.count(for: request)) == 0)
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
            $0.managedObjectContext = context
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
        let task = makeTask(in: context, name: "Stretch", interval: 14, lastDone: nil, emoji: "🤸")

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.managedObjectContext = context
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setEditSheet(true)) {
            $0.isEditSheetPresented = true
            $0.editRoutineName = "Stretch"
            $0.editRoutineEmoji = "🤸"
            $0.editFrequency = .week
            $0.editFrequencyValue = 2
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
            $0.managedObjectContext = context
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
            $0.managedObjectContext = context
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.editSaveTapped)

        #expect(store.state.task.name == "Original")
        #expect(store.state.task.interval == 10)
        #expect(store.state.isEditSheetPresented)
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
            $0.managedObjectContext = context
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
            $0.managedObjectContext = context
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

        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let request = NSFetchRequest<RoutineLog>(entityName: "RoutineLog")
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.predicate = NSPredicate(format: "task == %@", task)
            $0.logs = (try? context.fetch(request)) ?? []
            #expect($0.logs.count == 1)
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = true
        }

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "RoutineLog")
        #expect((try? context.count(for: request)) == 1)
        #expect(scheduledIDs.value == [task.objectID.uriRepresentation().absoluteString])
    }
}

@MainActor
private func makeInMemoryContext() -> NSManagedObjectContext {
    PersistenceController(inMemory: true).container.viewContext
}

@MainActor
private func makeTask(
    in context: NSManagedObjectContext,
    name: String?,
    interval: Int16,
    lastDone: Date?,
    emoji: String?
) -> RoutineTask {
    let task = RoutineTask(context: context)
    task.name = name
    task.interval = interval
    task.lastDone = lastDone
    task.setValue(emoji, forKey: "emoji")
    return task
}

@MainActor
private func makeLog(
    in context: NSManagedObjectContext,
    task: RoutineTask,
    timestamp: Date?
) -> RoutineLog {
    let log = RoutineLog(context: context)
    log.timestamp = timestamp
    log.task = task
    return log
}

private func makeDate(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: value) else {
        fatalError("Invalid ISO date string: \(value)")
    }
    return date
}
