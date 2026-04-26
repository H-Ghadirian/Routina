import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@Suite(.serialized)
@MainActor
struct TaskDetailFeatureTests {
    @Test
    func setDeleteConfirmation_togglesAlertPresentation() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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
    func addLinkedTaskRelationshipKindChanged_updatesSelectedKind() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.addLinkedTaskRelationshipKindChanged(.blockedBy)) {
            $0.addLinkedTaskRelationshipKind = .blockedBy
        }
    }

    @Test
    func deleteRoutineConfirmed_removesTaskCancelsNotificationAndRequestsDismiss() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Stretch", interval: 3, lastDone: nil, emoji: "🤸")
        _ = makeLog(in: context, task: task, timestamp: Date())
        try context.save()

        let canceledIDs = LockIsolated<[String]>([])
        let initialState = TaskDetailFeature.State(
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
            TaskDetailFeature()
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

        let initialState = TaskDetailFeature.State(
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
            TaskDetailFeature()
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
    func cancelTodo_marksOneOffTaskCanceledAndPersistsCanceledLog() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-18T10:00:00Z")
        let task = makeTask(
            in: context,
            name: "Buy milk",
            interval: 1,
            lastDone: nil,
            emoji: "🥛",
            scheduleMode: .oneOff
        )
        try context.save()
        let canceledIDs = LockIsolated<[String]>([])
        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { identifier in
                canceledIDs.withValue { $0.append(identifier) }
            }
        }
        store.exhaustivity = .off

        await store.send(.cancelTodo)
        #expect(store.state.task.canceledAt == now)
        #expect(store.state.taskRefreshID == 1)
        #expect(store.state.logs.count == 1)
        #expect(store.state.logs.first?.kind == .canceled)
        #expect(store.state.logs.first?.timestamp == now)

        var loadedLogs: [RoutineLog] = []
        await store.receive { action in
            guard case let .logsLoaded(logs) = action else { return false }
            loadedLogs = logs
            #expect(logs.count == 1)
            #expect(logs.first?.kind == .canceled)
            #expect(logs.first?.timestamp == now)
            return true
        } assert: {
            $0.logs = loadedLogs
        }

        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let savedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(savedTask.canceledAt == now)
        #expect(savedLogs.count == 1)
        #expect(savedLogs.first?.kind == .canceled)
        #expect(canceledIDs.value == [task.id.uuidString])
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
        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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
        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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
    func notTodayTapped_snoozesRoutineUntilTomorrowAndSchedulesReminder() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-14T10:00:00Z")
        let tomorrowStart = makeDate("2026-03-15T00:00:00Z")
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

        let scheduledIDs = LockIsolated<[String]>([])
        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.notTodayTapped) {
            $0.task.snoozedUntil = tomorrowStart
            $0.taskRefreshID = 1
        }

        #expect(store.state.task.pausedAt == nil)
        #expect(store.state.task.snoozedUntil == tomorrowStart)
        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(savedTask.pausedAt == nil)
        #expect(savedTask.snoozedUntil == tomorrowStart)
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

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-20T10:00:00Z")
        let expectedWeekday = calendar.component(.weekday, from: now)
        let expectedDayOfMonth = calendar.component(.day, from: now)

        await store.send(.setEditSheet(true)) {
            $0.isEditSheetPresented = true
            $0.editRoutineName = "Stretch"
            $0.editRoutineEmoji = "🤸"
            $0.editRoutineTags = ["Mobility", "Evening"]
            $0.editSelectedPlaceID = place.id
            $0.editFrequency = .week
            $0.editFrequencyValue = 2
            $0.editRecurrenceWeekday = expectedWeekday
            $0.editRecurrenceDayOfMonth = expectedDayOfMonth
        }
        await store.receive(.availablePlacesLoaded([
            RoutinePlaceSummary(id: place.id, name: "Gym", radiusMeters: place.radiusMeters, linkedRoutineCount: 1)
        ])) {
            $0.availablePlaces = [
                RoutinePlaceSummary(id: place.id, name: "Gym", radiusMeters: place.radiusMeters, linkedRoutineCount: 1)
            ]
        }
        await store.receive(.availableTagsLoaded(["Evening", "Mobility"])) {
            $0.availableTags = ["Evening", "Mobility"]
        }
        await store.receive(.relatedTagRulesLoaded([
            RoutineRelatedTagRule(tag: "Evening", relatedTags: ["Mobility"]),
            RoutineRelatedTagRule(tag: "Mobility", relatedTags: ["Evening"]),
        ])) {
            $0.relatedTagRules = [
                RoutineRelatedTagRule(tag: "Evening", relatedTags: ["Mobility"]),
                RoutineRelatedTagRule(tag: "Mobility", relatedTags: ["Evening"]),
            ]
        }
        await store.receive(.availableRelationshipTasksLoaded([]))
    }

    @Test
    func editAddTagTapped_parsesMultipleTagsAndDeduplicates() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let initialState = TaskDetailFeature.State(task: task, editRoutineTags: ["Focus"], editTagDraft: "night, focus")

        let store = TestStore(initialState: initialState) {
            TaskDetailFeature()
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
    func availableTagsLoaded_deduplicatesAndSortsChoices() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.availableTagsLoaded([" focus ", "Morning", "focus"])) {
            $0.availableTags = ["focus", "Morning"]
        }
    }

    @Test
    func editToggleTagSelection_addsAndRemovesChosenTag() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                editRoutineTags: ["Focus"],
                availableTags: ["Focus", "Night"]
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.editToggleTagSelection("Night")) {
            $0.editRoutineTags = ["Focus", "Night"]
        }

        await store.send(.editToggleTagSelection("focus")) {
            $0.editRoutineTags = ["Night"]
        }
    }

    @Test
    func editTagRenamed_updatesSelectedAndPersistedTags() async {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            tags: ["Focus", "Morning"]
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                editRoutineTags: ["Morning", "Focus"],
                availableTags: ["Focus", "Morning"]
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.editTagRenamed(oldName: "focus", newName: "Deep Work")) {
            $0.task.tags = ["Deep Work", "Morning"]
            $0.taskRefreshID = 1
            $0.editRoutineTags = ["Morning", "Deep Work"]
            $0.availableTags = ["Deep Work", "Morning"]
        }
    }

    @Test
    func editTagDeleted_removesTagFromSelectedAndPersistedTags() async {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            tags: ["Deep Work", "Morning"]
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                editRoutineTags: ["Morning", "Deep Work"],
                availableTags: ["Deep Work", "Morning"]
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.editTagDeleted("morning")) {
            $0.task.tags = ["Deep Work"]
            $0.taskRefreshID = 1
            $0.editRoutineTags = ["Deep Work"]
            $0.availableTags = ["Deep Work"]
        }
    }

    @Test
    func editRoutineEmojiChanged_sanitizesInputAndFallback() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let initialState = TaskDetailFeature.State(
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
            TaskDetailFeature()
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

        let initialState = TaskDetailFeature.State(
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
            TaskDetailFeature()
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
            initialState: TaskDetailFeature.State(
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
            TaskDetailFeature()
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
        await store.receive(.availableTagsLoaded(["Focus", "Night"])) {
            $0.availableTags = ["Focus", "Night"]
        }
        await store.receive(.relatedTagRulesLoaded([
            RoutineRelatedTagRule(tag: "Focus", relatedTags: ["Night"]),
            RoutineRelatedTagRule(tag: "Night", relatedTags: ["Focus"]),
        ])) {
            $0.relatedTagRules = [
                RoutineRelatedTagRule(tag: "Focus", relatedTags: ["Night"]),
                RoutineRelatedTagRule(tag: "Night", relatedTags: ["Focus"]),
            ]
        }
        await store.receive(.availableRelationshipTasksLoaded([]))
        await store.receive(.logsLoaded([]))
        await store.receive(.attachmentsLoaded([]))
        await receiveNotificationStatusLoaded(store)

        let persistedTaskID = task.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate<RoutineTask> { task in
                task.id == persistedTaskID
            }
        )
        let persistedTask = try #require(context.fetch(descriptor).first)
        #expect(persistedTask.name == "Deep Read")
        #expect(persistedTask.emoji == "🧠")
        #expect(persistedTask.interval == 14)
        #expect(persistedTask.tags == ["Focus", "Night"])
    }

    @Test
    func editSaveTapped_persistsEstimationValues() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-16T10:00:00Z")
        let task = makeTask(in: context, name: "Read", interval: 7, lastDone: nil, emoji: "📚")

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [],
                isEditSheetPresented: true,
                editRoutineName: "Read",
                editRoutineEmoji: "📚",
                editFrequency: .week,
                editFrequencyValue: 1,
                editEstimatedDurationMinutes: 95,
                editStoryPoints: 3
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }

        await store.receive(.onAppear) {
            $0.selectedDate = makeTestCalendar().startOfDay(for: now)
        }
        await store.receive(.availablePlacesLoaded([]))
        await store.receive(.availableTagsLoaded([]))
        await store.receive(.relatedTagRulesLoaded([]))
        await store.receive(.availableRelationshipTasksLoaded([]))
        await store.receive(.logsLoaded([]))
        await store.receive(.attachmentsLoaded([]))
        await receiveNotificationStatusLoaded(store)

        let persistedTaskID = task.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate<RoutineTask> { task in
                task.id == persistedTaskID
            }
        )
        let persistedTask = try #require(context.fetch(descriptor).first)
        #expect(persistedTask.estimatedDurationMinutes == 95)
        #expect(persistedTask.storyPoints == 3)
    }

    @Test
    func editSaveTapped_normalizesAndPersistsLink() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-16T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(in: context, name: "Read", interval: 7, lastDone: nil, emoji: "📚")

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [],
                isEditSheetPresented: true,
                editRoutineName: "Read",
                editRoutineEmoji: "📚",
                editRoutineLink: "example.com/article",
                editFrequency: .week,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
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
        await store.receive(.availablePlacesLoaded([]))
        await store.receive(.availableTagsLoaded([]))
        await store.receive(.relatedTagRulesLoaded([]))
        await store.receive(.availableRelationshipTasksLoaded([]))
        await store.receive(.logsLoaded([]))
        await store.receive(.attachmentsLoaded([]))
        await receiveNotificationStatusLoaded(store)

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
        #expect(persistedTask.link == "https://example.com/article")
        #expect(persistedTask.resolvedLinkURL?.absoluteString == "https://example.com/article")
    }

    @Test
    func editSaveTapped_rejectsDuplicateName_caseInsensitiveAndTrimmed() async throws {
        let context = makeInMemoryContext()
        _ = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        let editableTask = makeTask(in: context, name: "Workout", interval: 3, lastDone: nil, emoji: "💪")
        try context.save()

        let initialState = TaskDetailFeature.State(
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
            TaskDetailFeature()
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
            initialState: TaskDetailFeature.State(
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
            TaskDetailFeature()
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
        await store.receive(.availableTagsLoaded([]))
        await store.receive(.relatedTagRulesLoaded([]))
        await store.receive(.availableRelationshipTasksLoaded([]))
        await store.receive(.logsLoaded([]))
        await store.receive(.attachmentsLoaded([]))
        await receiveNotificationStatusLoaded(store)

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
    func editSaveTapped_persistsWeeklyExactTimeRecurrence() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-16T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(
            in: context,
            name: "Review Week",
            interval: 7,
            lastDone: nil,
            emoji: "🗂️",
            recurrenceRule: .weekly(on: 6),
            scheduleAnchor: makeDate("2026-03-16T10:00:00Z")
        )

        let exactTime = RoutineTimeOfDay(hour: 18, minute: 45)
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Review Week",
                editRoutineEmoji: "🗂️",
                editRecurrenceKind: .weekly,
                editRecurrenceHasExplicitTime: true,
                editRecurrenceTimeOfDay: exactTime,
                editRecurrenceWeekday: 6
            )
        ) {
            TaskDetailFeature()
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
        await store.receive(.availablePlacesLoaded([]))
        await store.receive(.availableTagsLoaded([]))
        await store.receive(.relatedTagRulesLoaded([]))
        await store.receive(.availableRelationshipTasksLoaded([]))
        await store.receive(.logsLoaded([]))
        await store.receive(.attachmentsLoaded([]))
        await receiveNotificationStatusLoaded(store)

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
        #expect(persistedTask.recurrenceRule == .weekly(on: 6, at: exactTime))
    }

    @Test
    func editSaveTapped_switchesFromFixedToChecklistAndClearsSteps() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-16T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(
            in: context,
            name: "Laundry",
            interval: 7,
            lastDone: nil,
            emoji: "🧺",
            steps: [
                RoutineStep(title: "Sort clothes"),
                RoutineStep(title: "Start washer")
            ],
            scheduleMode: .fixedInterval
        )
        let checklistItems = [
            RoutineChecklistItem(title: "Whites", intervalDays: 3, createdAt: now),
            RoutineChecklistItem(title: "Colors", intervalDays: 3, createdAt: now)
        ]

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Laundry",
                editRoutineEmoji: "🧺",
                editScheduleMode: .fixedIntervalChecklist,
                editRoutineSteps: task.steps,
                editRoutineChecklistItems: checklistItems,
                editFrequency: .week,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
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
        await store.receive(.availablePlacesLoaded([]))
        await store.receive(.availableTagsLoaded([]))
        await store.receive(.relatedTagRulesLoaded([]))
        await store.receive(.availableRelationshipTasksLoaded([]))
        await store.receive(.logsLoaded([]))
        await store.receive(.attachmentsLoaded([]))
        await receiveNotificationStatusLoaded(store)

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
        #expect(persistedTask.scheduleMode == .fixedIntervalChecklist)
        #expect(persistedTask.steps.isEmpty)
        #expect(persistedTask.checklistItems.map(\.title) == ["Whites", "Colors"])
    }

    @Test
    func editSaveTapped_switchesToRunoutAndPersistsChecklistIntervals() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-16T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(
            in: context,
            name: "Pantry",
            interval: 5,
            lastDone: nil,
            emoji: "🥫",
            steps: [RoutineStep(title: "Check shelves")],
            scheduleMode: .fixedInterval
        )
        let checklistItems = [
            RoutineChecklistItem(title: "Beans", intervalDays: 14, createdAt: now),
            RoutineChecklistItem(title: "Rice", intervalDays: 30, createdAt: now)
        ]

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Pantry",
                editRoutineEmoji: "🥫",
                editScheduleMode: .derivedFromChecklist,
                editRoutineSteps: task.steps,
                editRoutineChecklistItems: checklistItems,
                editFrequency: .day,
                editFrequencyValue: 5
            )
        ) {
            TaskDetailFeature()
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
        await store.receive(.availablePlacesLoaded([]))
        await store.receive(.availableTagsLoaded([]))
        await store.receive(.relatedTagRulesLoaded([]))
        await store.receive(.availableRelationshipTasksLoaded([]))
        await store.receive(.logsLoaded([]))
        await store.receive(.attachmentsLoaded([]))
        await receiveNotificationStatusLoaded(store)

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
        #expect(persistedTask.scheduleMode == .derivedFromChecklist)
        #expect(persistedTask.steps.isEmpty)
        #expect(persistedTask.checklistItems.map(\.intervalDays) == [14, 30])
        #expect(persistedTask.checklistItems.map(\.title) == ["Beans", "Rice"])
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

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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
        await store.receive(.availableTagsLoaded([]))
        await store.receive(.relatedTagRulesLoaded([]))
        await store.receive(.availableRelationshipTasksLoaded([]))
        await store.receive(.logsLoaded([]))
        await store.receive(.attachmentsLoaded([]))
        await receiveNotificationStatusLoaded(store)
    }

    @Test
    func markAsDone_setsImmediateStateAndPersistsLog() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let task = makeTask(in: context, name: "Hydrate", interval: 2, lastDone: nil, emoji: "💧")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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
            if case .attachmentsLoaded = $0 { return true }
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
    func markAsDone_forOneOffTaskCancelsNotification() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T10:00:00Z")
        let task = makeTask(
            in: context,
            name: "Pay rent",
            interval: 1,
            lastDone: nil,
            emoji: "🏠",
            scheduleMode: .oneOff
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let canceledIDs = LockIsolated<[String]>([])

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.cancel = { identifier in
                canceledIDs.withValue { $0.append(identifier) }
            }
        }

        await store.send(.markAsDone) {
            $0.taskRefreshID = 1
            $0.isDoneToday = true
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
        }

        await store.receive {
            if case .logsLoaded = $0 { return true }
            if case .attachmentsLoaded = $0 { return true }
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

        let persistedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(persistedTask.lastDone == now)
        #expect(persistedTask.scheduleMode == .oneOff)
        #expect(persistedLogs.count == 1)
        #expect(canceledIDs.value == [task.id.uuidString])
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

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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
            if case .attachmentsLoaded = $0 { return true }
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

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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
            if case .attachmentsLoaded = $0 { return true }
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

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
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

        let initialState = TaskDetailFeature.State(
            task: task,
            logs: [RoutineLog(timestamp: todayLog, taskID: task.id)],
            selectedDate: selectedDayStart,
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: true
        )

        let store = TestStore(initialState: initialState) {
            TaskDetailFeature()
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
            if case .attachmentsLoaded = $0 { return true }
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

        let initialState = TaskDetailFeature.State(
            task: task,
            logs: [existingLog],
            selectedDate: selectedDayStart,
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: true
        )

        let store = TestStore(initialState: initialState) {
            TaskDetailFeature()
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
        let initialState = TaskDetailFeature.State(
            task: task,
            logs: [todayLog],
            selectedDate: calendar.startOfDay(for: now),
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: true
        )

        let store = TestStore(initialState: initialState) {
            TaskDetailFeature()
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
        let initialState = TaskDetailFeature.State(
            task: task,
            logs: [todayLog, olderLog],
            selectedDate: selectedDayStart,
            daysSinceLastRoutine: 0,
            overdueDays: 0,
            isDoneToday: true
        )

        let store = TestStore(initialState: initialState) {
            TaskDetailFeature()
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

@MainActor
private func receiveNotificationStatusLoaded(_ store: TestStoreOf<TaskDetailFeature>) async {
    await store.receive(.notificationStatusLoaded(appEnabled: false, systemAuthorized: false)) {
        $0.hasLoadedNotificationStatus = true
        $0.appNotificationsEnabled = false
        $0.systemNotificationsAuthorized = false
    }
}
