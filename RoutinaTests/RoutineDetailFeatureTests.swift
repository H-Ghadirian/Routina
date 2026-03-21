import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import Routina

@Suite(.serialized)
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
    func pauseTapped_persistsArchivedStateAndCancelsNotification() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-14T10:00:00Z")
        let anchorDate = makeDate("2026-03-10T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 5,
            lastDone: nil,
            emoji: "📚",
            scheduleAnchor: anchorDate
        )
        try context.save()

        let canceledIDs = LockIsolated<[String]>([])
        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { identifier in
                canceledIDs.withValue { $0.append(identifier) }
            }
        }

        await store.send(.pauseTapped) {
            $0.taskRefreshID = 1
        }

        #expect(store.state.task.pausedAt == now)
        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(savedTask.pausedAt == now)
        #expect(canceledIDs.value == [task.id.uuidString])
    }

    @Test
    func resumeTapped_restoresRoutineAndSchedulesNotification() async throws {
        let context = makeInMemoryContext()
        let pauseDate = makeDate("2026-03-10T10:00:00Z")
        let resumeDate = makeDate("2026-03-14T10:00:00Z")
        let anchorDate = makeDate("2026-03-05T10:00:00Z")
        let expectedAnchor = anchorDate.addingTimeInterval(resumeDate.timeIntervalSince(pauseDate))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(
            in: context,
            name: "Stretch",
            interval: 5,
            lastDone: nil,
            emoji: "🤸",
            scheduleAnchor: anchorDate,
            pausedAt: pauseDate
        )
        try context.save()

        let scheduledIDs = LockIsolated<[String]>([])
        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = resumeDate
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.resumeTapped) {
            $0.taskRefreshID = 1
        }

        #expect(store.state.task.scheduleAnchor == expectedAnchor)
        #expect(store.state.task.pausedAt == nil)
        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(savedTask.pausedAt == nil)
        #expect(savedTask.scheduleAnchor == expectedAnchor)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func setEditSheetTrue_syncsEditFormFromTask_weekFrequency() async {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Gym")
        let task = makeTask(
            in: context,
            name: "Stretch",
            interval: 14,
            lastDone: nil,
            emoji: "🤸",
            placeID: place.id,
            tags: ["Mobility", "Evening"]
        )

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
            $0.editSelectedPlaceID = place.id
            $0.editFrequency = .week
            $0.editFrequencyValue = 2
        }
        await store.receive(.availablePlacesLoaded([
            RoutinePlaceSummary(id: place.id, name: "Gym", radiusMeters: place.radiusMeters, linkedRoutineCount: 1)
        ])) {
            $0.availablePlaces = [
                RoutinePlaceSummary(id: place.id, name: "Gym", radiusMeters: place.radiusMeters, linkedRoutineCount: 1)
            ]
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
            setTestDateDependencies(&$0)
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
            setTestDateDependencies(&$0)
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
            setTestDateDependencies(&$0)
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
        let now = makeDate("2026-03-16T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
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
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.editSaveTapped) {
            $0.editRoutineTags = ["Focus", "Night"]
            $0.editTagDraft = ""
            $0.isEditSheetPresented = false
        }

        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }
        await store.receive(.availablePlacesLoaded([]))
        await store.receive(.logsLoaded([]))

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
            setTestDateDependencies(&$0)
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
    func editSaveTapped_persistsSelectedPlaceID() async throws {
        let context = makeInMemoryContext()
        let home = makePlace(in: context, name: "Home")
        let office = makePlace(in: context, name: "Office")
        let task = makeTask(in: context, name: "Review Tasks", interval: 3, lastDone: nil, emoji: "🗂️", placeID: home.id)

        let now = makeDate("2026-03-16T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let store = TestStore(
            initialState: RoutineDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Review Tasks",
                editRoutineEmoji: "🗂️",
                availablePlaces: [
                    RoutinePlaceSummary(id: home.id, name: "Home", radiusMeters: home.radiusMeters, linkedRoutineCount: 1),
                    RoutinePlaceSummary(id: office.id, name: "Office", radiusMeters: office.radiusMeters, linkedRoutineCount: 0)
                ],
                editSelectedPlaceID: office.id,
                editFrequency: .day,
                editFrequencyValue: 3
            )
        ) {
            RoutineDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }

        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }
        await store.receive {
            guard case let .availablePlacesLoaded(places) = $0 else { return false }
            #expect(places.count == 2)
            #expect(places == [
                RoutinePlaceSummary(id: home.id, name: "Home", radiusMeters: home.radiusMeters, linkedRoutineCount: 0),
                RoutinePlaceSummary(id: office.id, name: "Office", radiusMeters: office.radiusMeters, linkedRoutineCount: 1)
            ])
            return true
        } assert: {
            $0.availablePlaces = [
                RoutinePlaceSummary(id: home.id, name: "Home", radiusMeters: home.radiusMeters, linkedRoutineCount: 0),
                RoutinePlaceSummary(id: office.id, name: "Office", radiusMeters: office.radiusMeters, linkedRoutineCount: 1)
            ]
        }
        await store.receive(.logsLoaded([]))

        let persistedTaskID = task.id
        let persistedTask = try #require(
            context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { persistedTask in
                        persistedTask.id == persistedTaskID
                    }
                )
            ).first
        )
        #expect(persistedTask.placeID == office.id)
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

        await store.receive(.availablePlacesLoaded([]))
        await store.receive(.logsLoaded([]))
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
            $0.taskRefreshID = 1
            $0.isDoneToday = true
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
        }
        #expect(store.state.task.lastDone == now)
        #expect(store.state.task.scheduleAnchor == now)

        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let verificationContext = ModelContext(context.container)
            let descriptor = FetchDescriptor<RoutineLog>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            $0.logs = ((try? verificationContext.fetch(descriptor)) ?? []).filter { $0.taskID == task.id }
            #expect($0.logs.count == 1)
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = true
        }

        let verificationContext = ModelContext(context.container)
        let persistedLogs = (try? verificationContext.fetch(FetchDescriptor<RoutineLog>())) ?? []
        let persistedTask = try? verificationContext.fetch(FetchDescriptor<RoutineTask>()).first
        #expect(persistedLogs.count == 1)
        #expect(persistedTask != nil)
        #expect(persistedTask?.scheduleAnchor == now)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func markAsDone_forChecklistRoutine_updatesDueItemsAndPersistsSingleLog() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-20T10:00:00Z")
        let createdAt = makeDate("2026-03-15T10:00:00Z")
        let task = makeTask(
            in: context,
            name: "Do groceries",
            interval: 1,
            lastDone: nil,
            emoji: "🛒",
            checklistItems: [
                RoutineChecklistItem(title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(title: "Milk", intervalDays: 7, createdAt: createdAt)
            ],
            scheduleMode: .derivedFromChecklist
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        _ = await store.withExhaustivity(.off) {
            await store.send(.markAsDone) {
                $0.taskRefreshID = 1
                $0.isDoneToday = true
                $0.daysSinceLastRoutine = 0
                $0.overdueDays = 0
            }
        }

        #expect(store.state.isDoneToday)
        #expect(store.state.daysSinceLastRoutine == 0)
        #expect(store.state.overdueDays == 0)
        #expect(store.state.logs.count == 1)

        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let verificationContext = ModelContext(context.container)
            let descriptor = FetchDescriptor<RoutineLog>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            $0.logs = ((try? verificationContext.fetch(descriptor)) ?? []).filter { $0.taskID == task.id }
            #expect($0.logs.count == 1)
            $0.isDoneToday = true
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
        }

        let persistedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let bread = try #require(persistedTask.checklistItems.first(where: { $0.title == "Bread" }))
        let milk = try #require(persistedTask.checklistItems.first(where: { $0.title == "Milk" }))
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(bread.lastPurchasedAt == now)
        #expect(milk.lastPurchasedAt == nil)
        #expect(persistedLogs.count == 1)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func markChecklistItemCompleted_forCompletionChecklist_completesOnlyAfterFinalItem() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-20T10:00:00Z")
        let shoesID = UUID()
        let towelID = UUID()
        let task = makeTask(
            in: context,
            name: "Pack gym bag",
            interval: 2,
            lastDone: nil,
            emoji: "🎒",
            checklistItems: [
                RoutineChecklistItem(id: shoesID, title: "Shoes", intervalDays: 3, createdAt: now),
                RoutineChecklistItem(id: towelID, title: "Towel", intervalDays: 3, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.markChecklistItemCompleted(shoesID)) {
            $0.taskRefreshID = 1
        }
        #expect(store.state.task.completedChecklistItemCount == 1)
        #expect(store.state.logs.isEmpty)
        #expect(!store.state.isDoneToday)

        await store.receive(.logsLoaded([]))

        let persistedAfterFirst = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let logsAfterFirst = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedAfterFirst.completedChecklistItemCount == 1)
        #expect(logsAfterFirst.isEmpty)

        _ = await store.withExhaustivity(.off) {
            await store.send(.markChecklistItemCompleted(towelID)) {
                $0.taskRefreshID = 2
                $0.isDoneToday = true
                $0.daysSinceLastRoutine = 0
                $0.overdueDays = 0
                #expect($0.logs.count == 1)
            }
        }

        await store.receive {
            if case .logsLoaded = $0 { return true }
            return false
        } assert: {
            let verificationContext = ModelContext(context.container)
            let descriptor = FetchDescriptor<RoutineLog>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            $0.logs = ((try? verificationContext.fetch(descriptor)) ?? []).filter { $0.taskID == task.id }
            #expect($0.logs.count == 1)
            $0.isDoneToday = true
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
        }

        let persistedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.completedChecklistItemCount == 0)
        #expect(persistedTask.lastDone == now)
        #expect(persistedLogs.count == 1)
        #expect(scheduledIDs.value == [task.id.uuidString, task.id.uuidString])
    }

    @Test
    func toggleChecklistItemCompletion_forCompletionChecklist_canClearInProgressItem() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-20T10:00:00Z")
        let shoesID = UUID()
        let towelID = UUID()
        let task = makeTask(
            in: context,
            name: "Pack gym bag",
            interval: 2,
            lastDone: nil,
            emoji: "🎒",
            checklistItems: [
                RoutineChecklistItem(id: shoesID, title: "Shoes", intervalDays: 3, createdAt: now),
                RoutineChecklistItem(id: towelID, title: "Towel", intervalDays: 3, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let store = TestStore(initialState: RoutineDetailFeature.State(task: task)) {
            RoutineDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.toggleChecklistItemCompletion(shoesID)) {
            $0.taskRefreshID = 1
        }
        #expect(store.state.task.completedChecklistItemCount == 1)
        #expect(store.state.logs.isEmpty)
        #expect(!store.state.isDoneToday)

        await store.receive(.logsLoaded([]))

        await store.send(.toggleChecklistItemCompletion(shoesID)) {
            $0.taskRefreshID = 2
            $0.task.resetChecklistProgress()
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = false
        }

        await store.receive(.logsLoaded([]))

        let persistedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.completedChecklistItemCount == 0)
        #expect(persistedLogs.isEmpty)
    }

    @Test
    func markAsDone_forStepRoutine_advancesWithoutCreatingCompletionLog() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let task = makeTask(
            in: context,
            name: "Laundry",
            interval: 2,
            lastDone: nil,
            emoji: "🧺",
            steps: [
                RoutineStep(title: "Wash clothes"),
                RoutineStep(title: "Hang on the line"),
                RoutineStep(title: "Put away")
            ]
        )

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
            $0.taskRefreshID = 1
        }
        #expect(store.state.task.completedStepCount == 1)
        #expect(store.state.task.sequenceStartedAt == now)

        await store.receive(.logsLoaded([]))

        let verificationContext = ModelContext(context.container)
        let persistedTask = try #require(try verificationContext.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = try verificationContext.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.completedStepCount == 1)
        #expect(persistedTask.lastDone == nil)
        #expect(persistedLogs.isEmpty)
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

        await store.send(.markAsDone) {
            $0.taskRefreshID = 1
        }

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
                    predicate: #Predicate<RoutineTask> { persistedTask in
                        persistedTask.id == persistedTaskID
                    }
                )
            ).first
        )
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.lastDone == now)
        #expect(persistedTask.scheduleAnchor == now)
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

        await store.send(.markAsDone) {
            $0.taskRefreshID = 1
        }

        await store.receive(.logsLoaded([existingLog]))

        let persistedTaskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { persistedTask in
                        persistedTask.id == persistedTaskID
                    }
                )
            ).first
        )
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.lastDone == now)
        #expect(persistedTask.scheduleAnchor == now)
        #expect(persistedLogs.count == 1)
        #expect(scheduledIDs.value.isEmpty)
    }

    @Test
    func undoSelectedDateCompletion_forToday_removesCompletionAndReschedules() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let task = makeTask(in: context, name: "Hydrate", interval: 2, lastDone: now, emoji: "💧")
        let todayLog = makeLog(in: context, task: task, timestamp: now)
        try context.save()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])
        let initialState = RoutineDetailFeature.State(
            task: task,
            logs: [todayLog],
            selectedDate: calendar.startOfDay(for: now),
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

        await store.send(.undoSelectedDateCompletion) {
            $0.taskRefreshID = 1
            $0.task.lastDone = nil
            $0.task.scheduleAnchor = nil
            $0.logs = []
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = false
        }

        await store.receive(.logsLoaded([]))

        let persistedTask = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.lastDone == nil)
        #expect(persistedTask.scheduleAnchor == nil)
        #expect(persistedLogs.isEmpty)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func undoSelectedDateCompletion_forPastDate_removesOnlySelectedCompletion() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let olderCompletion = makeDate("2026-02-24T12:00:00Z")
        let task = makeTask(in: context, name: "Hydrate", interval: 2, lastDone: now, emoji: "💧")
        let todayLog = makeLog(in: context, task: task, timestamp: now)
        let olderLog = makeLog(in: context, task: task, timestamp: olderCompletion)
        try context.save()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])
        let selectedDayStart = calendar.startOfDay(for: olderCompletion)
        let initialState = RoutineDetailFeature.State(
            task: task,
            logs: [todayLog, olderLog],
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

        await store.send(.undoSelectedDateCompletion) {
            $0.taskRefreshID = 1
            $0.task.lastDone = now
            $0.task.scheduleAnchor = now
            $0.logs = [todayLog]
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = true
        }

        await store.receive(.logsLoaded([todayLog]))

        let persistedTask = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.lastDone == now)
        #expect(persistedTask.scheduleAnchor == now)
        #expect(persistedLogs.count == 1)
        #expect(persistedLogs.first?.timestamp == now)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }
}
