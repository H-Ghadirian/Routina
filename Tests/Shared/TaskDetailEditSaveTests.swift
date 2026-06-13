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
struct TaskDetailEditSaveTests {
    @Test
    func editAllDayChanged_forTodoWithoutDeadlineDoesNotCreateDeadline() async {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = RoutineTask(
            name: "Buy tickets",
            scheduleMode: .oneOff
        )
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Buy tickets",
                editRoutineEmoji: "🎟️",
                editScheduleMode: .oneOff,
                editRecurrenceHasExplicitTime: true,
                editRecurrenceHasTimeRange: true
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }

        await store.send(.editAllDayChanged(true)) {
            $0.editIsAllDay = true
            $0.editRecurrenceHasExplicitTime = false
            $0.editRecurrenceHasTimeRange = false
        }

        #expect(store.state.editDeadline == nil)
    }

    @Test
    func editDeadlineDisabled_preservesTodoAllDayFlag() async {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let deadline = makeDate("2026-03-14T18:45:00Z")
        let task = RoutineTask(
            name: "Conference",
            deadline: deadline,
            isAllDay: true,
            scheduleMode: .oneOff
        )
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Conference",
                editRoutineEmoji: "🎟️",
                editDeadline: deadline,
                editIsAllDay: true,
                editScheduleMode: .oneOff
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }

        await store.send(.editDeadlineEnabledChanged(false)) {
            $0.editDeadline = nil
        }

        #expect(store.state.editIsAllDay)
    }

    @Test
    func editSelectedPlaceIDsChanged_tracksMultiplePlacesAndPrimaryFallback() async {
        let homeID = UUID()
        let gymID = UUID()
        let task = RoutineTask(name: "Stretch")
        let store = TestStore(
            initialState: TaskDetailFeature.State(task: task)
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
        }

        await store.send(.editSelectedPlaceIDsChanged([homeID, gymID])) {
            $0.editSelectedPlaceIDs = [homeID, gymID]
            $0.editSelectedPlaceID = homeID
        }
    }

    @Test
    func editSaveTapped_persistsMultipleSelectedPlaceIDs() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let home = makePlace(in: context, name: "Home")
        let gym = makePlace(in: context, name: "Gym")
        let task = makeTask(
            in: context,
            name: "Stretch",
            interval: 3,
            lastDone: nil,
            emoji: "🤸",
            placeID: home.id
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Stretch",
                editRoutineEmoji: "🤸",
                editSelectedPlaceID: home.id,
                editSelectedPlaceIDs: [home.id, gym.id],
                editFrequency: .day,
                editFrequencyValue: 3
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear)

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.placeID == home.id)
        #expect(persistedTask.placeIDs == [home.id, gym.id])
    }

    @Test
    func editSaveTapped_persistsLinkedEventIDs() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let event = RoutineEvent(
            title: "Appointment",
            startedAt: makeDate("2026-03-12T10:00:00Z")
        )
        context.insert(event)
        let task = makeTask(
            in: context,
            name: "Prepare notes",
            interval: 3,
            lastDone: nil,
            emoji: "📝"
        )

        let eventCandidate = RoutineEventLinkCandidate(event: event)
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Prepare notes",
                editRoutineEmoji: "📝",
                availableEvents: [eventCandidate],
                editFrequency: .day,
                editFrequencyValue: 3
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editToggleEventSelection(event.id)) {
            $0.editEventIDs = [event.id]
        }
        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear)

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.eventIDs == [event.id])
    }

    @Test
    func editSaveTapped_persistsAllDayFlagForDatedTodos() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let deadline = makeDate("2026-03-14T18:45:00Z")
        let task = RoutineTask(
            name: "Conference",
            deadline: deadline,
            scheduleMode: .oneOff
        )
        context.insert(task)
        try context.save()

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Conference",
                editRoutineEmoji: "🎟️",
                editDeadline: deadline,
                editScheduleMode: .oneOff
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editAllDayChanged(true)) {
            $0.editIsAllDay = true
            $0.editDeadline = calendar.startOfDay(for: deadline)
        }
        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear)

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.deadline == calendar.startOfDay(for: deadline))
        #expect(persistedTask.isAllDay)
    }

    @Test
    func editSaveTapped_persistsWindowAvailabilityForTodos() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = RoutineTask(
            name: "Call landlord",
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1)
        )
        context.insert(task)
        try context.save()
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Call landlord",
                editRoutineEmoji: "📞",
                editScheduleMode: .oneOff,
                editFrequency: .day,
                editFrequencyValue: 1,
                editRecurrenceKind: .intervalDays,
                editRecurrenceHasTimeRange: true,
                editRecurrenceTimeRangeStart: window.start,
                editRecurrenceTimeRangeEnd: window.end
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear)

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.scheduleMode == .oneOff)
        #expect(persistedTask.deadline == nil)
        #expect(persistedTask.recurrenceRule == .interval(days: 1, timeRange: window))
    }

    @Test
    func editSaveTapped_persistsAllDayFlagForRoutines() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = RoutineTask(
            name: "Studio day",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1)
        )
        context.insert(task)
        try context.save()

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Studio day",
                editRoutineEmoji: "🎨",
                editScheduleMode: .fixedInterval,
                editFrequency: .day,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editAllDayChanged(true)) {
            $0.editIsAllDay = true
        }
        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear)

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.scheduleMode == .fixedInterval)
        #expect(persistedTask.deadline == nil)
        #expect(persistedTask.isAllDay)
    }

    @Test
    func editSaveTapped_persistsRoutineDurationIndependentOfAllDay() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = RoutineTask(
            name: "Travel",
            isAllDay: false,
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(on: 3)
        )
        context.insert(task)
        try context.save()

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Travel",
                editRoutineEmoji: "✈️",
                editIsAllDay: false,
                editRoutineDurationMode: .oneDay,
                editScheduleMode: .fixedInterval,
                editFrequency: .day,
                editFrequencyValue: 1,
                editRecurrenceKind: .weekly,
                editRecurrenceWeekday: 3
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editRoutineDurationModeChanged(.multiDay)) {
            $0.editRoutineDurationMode = .multiDay
        }
        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear)

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.scheduleMode == .fixedInterval)
        #expect(!persistedTask.isAllDay)
        #expect(persistedTask.routineDurationMode == .multiDay)
    }

    @Test
    func editSaveTapped_multiDayRoutineClampsDailyIntervalToTwoDays() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Travel prep",
            interval: 1,
            lastDone: nil,
            emoji: "✈️",
            recurrenceRule: .interval(days: 1),
            scheduleAnchor: makeDate("2026-03-10T06:00:00Z")
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Travel prep",
                editRoutineEmoji: "✈️",
                editRoutineDurationMode: .multiDay,
                editScheduleMode: .fixedInterval,
                editFrequency: .day,
                editFrequencyValue: 1,
                editRecurrenceKind: .intervalDays
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear)

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.routineDurationMode == .multiDay)
        #expect(persistedTask.recurrenceRule == .interval(days: 2))
    }

    @Test
    func editSaveTapped_allDayRoutineIgnoresStaleAvailabilityTiming() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Water plants",
            interval: 7,
            lastDone: nil,
            emoji: "🪴",
            recurrenceRule: .interval(days: 7, at: RoutineTimeOfDay(hour: 20, minute: 0)),
            scheduleAnchor: makeDate("2026-03-10T06:00:00Z")
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Water plants",
                editRoutineEmoji: "🪴",
                editIsAllDay: true,
                editScheduleMode: .fixedInterval,
                editFrequency: .week,
                editFrequencyValue: 1,
                editRecurrenceKind: .intervalDays,
                editRecurrenceHasExplicitTime: true,
                editRecurrenceHasTimeRange: true,
                editRecurrenceTimeOfDay: RoutineTimeOfDay(hour: 20, minute: 0),
                editRecurrenceTimeRangeStart: RoutineTimeOfDay(hour: 19, minute: 0),
                editRecurrenceTimeRangeEnd: RoutineTimeOfDay(hour: 21, minute: 0)
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.isAllDay)
        #expect(persistedTask.recurrenceRule == .interval(days: 7))
    }

    @Test
    func editSaveTapped_persistsVoiceNoteChange() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let voiceNote = RoutineVoiceNote(
            data: Data([0x09, 0x08, 0x07]),
            durationSeconds: 8,
            createdAt: now
        )
        let task = makeTask(
            in: context,
            name: "Call supplier",
            interval: 1,
            lastDone: nil,
            emoji: "☎️"
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Call supplier",
                editRoutineEmoji: "☎️",
                editVoiceNote: voiceNote,
                editScheduleMode: .fixedInterval,
                editFrequency: .day,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear)

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.voiceNote == voiceNote)
        #expect(persistedTask.hasVoiceNote)
    }

    @Test
    func editSaveTapped_preservesCreatedAtAndLogsOnMetadataEdit() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let createdAt = makeDate("2026-01-05T08:00:00Z")
        let logDate = makeDate("2026-01-12T12:00:00Z")
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 7,
            lastDone: nil,
            emoji: "📚",
            createdAt: createdAt
        )
        _ = makeLog(in: context, task: task, timestamp: logDate)

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Read deeply",
                editRoutineEmoji: "📚",
                editScheduleMode: .fixedInterval,
                editFrequency: .week,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
            $0.task.scheduleAnchor = createdAt
            $0.overdueDays = RoutineDateMath.overdueDays(
                for: $0.task,
                referenceDate: now,
                calendar: calendar
            )
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        let persistedLogs = try context.fetch(
            FetchDescriptor<RoutineLog>(
                predicate: #Predicate<RoutineLog> { log in
                    log.taskID == taskID
                }
            )
        )
        #expect(persistedTask.name == "Read deeply")
        #expect(persistedTask.createdAt == createdAt)
        #expect(persistedTask.scheduleAnchor == createdAt)
        #expect(persistedLogs.count == 1)
        #expect(persistedLogs.first?.timestamp == logDate)
    }

    @Test
    func editSaveTapped_doesNotStampLegacyNilCreatedAtOnMetadataEdit() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Legacy",
            interval: 3,
            lastDone: nil,
            emoji: "🧭",
            createdAt: nil
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Legacy updated",
                editRoutineEmoji: "🧭",
                editScheduleMode: .fixedInterval,
                editFrequency: .day,
                editFrequencyValue: 3
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.name == "Legacy updated")
        #expect(persistedTask.createdAt == nil)
        #expect(persistedTask.scheduleAnchor == nil)
    }

    @Test
    func editSaveTapped_removingAllChecklistItemsConvertsToFixedRoutine() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Restock pantry",
            interval: 7,
            lastDone: nil,
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(title: "Beans", intervalDays: 14, createdAt: now),
                RoutineChecklistItem(title: "Rice", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Restock pantry",
                editRoutineEmoji: "✨",
                editScheduleMode: .fixedIntervalChecklist,
                editRoutineChecklistItems: [],
                editFrequency: .week,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.scheduleMode == .fixedInterval)
        #expect(persistedTask.checklistItems.isEmpty)
    }

    @Test
    func editSaveTapped_switchingToChecklistWithoutItemsShowsValidation() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Restock pantry",
            interval: 7,
            lastDone: nil,
            emoji: "✨",
            scheduleMode: .fixedInterval
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Restock pantry",
                editRoutineEmoji: "✨",
                editScheduleMode: .fixedIntervalChecklist,
                editRoutineChecklistItems: [],
                editFrequency: .week,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.editSaveTapped) {
            $0.editChecklistValidationMessage = AddRoutineChecklistValidator.missingRequiredChecklistItemMessage
        }

        #expect(store.state.isEditSheetPresented)
    }

    @Test
    func editSaveTapped_persistsChecklistItemsForStandardRoutine() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Plan workshop",
            interval: 7,
            lastDone: nil,
            emoji: "✨",
            scheduleMode: .fixedInterval
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Plan workshop",
                editRoutineEmoji: "✨",
                editScheduleMode: .fixedInterval,
                editRoutineChecklistItems: [RoutineChecklistItem(title: "Book room", intervalDays: 1)],
                editFrequency: .week,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.scheduleMode == .fixedInterval)
        #expect(persistedTask.checklistItems.map(\.title) == ["Book room"])
    }

    @Test
    func editSaveTapped_persistsChecklistItemsForTodo() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Buy ingredients",
            interval: 1,
            lastDone: nil,
            emoji: "✨",
            scheduleMode: .oneOff
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Buy ingredients",
                editRoutineEmoji: "✨",
                editScheduleMode: .oneOff,
                editRoutineChecklistItems: [RoutineChecklistItem(title: "Flour", intervalDays: 1)],
                editFrequency: .day,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.scheduleMode == .oneOff)
        #expect(persistedTask.checklistItems.map(\.title) == ["Flour"])
    }

    @Test
    func editSaveTapped_persistsDailyTimeRangeRecurrence() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Breakfast",
            interval: 1,
            lastDone: nil,
            emoji: "🍳",
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 8, minute: 0)),
            scheduleAnchor: makeDate("2026-03-10T06:00:00Z")
        )
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Breakfast",
                editRoutineEmoji: "🍳",
                editScheduleMode: .fixedInterval,
                editRecurrenceKind: .dailyTime,
                editRecurrenceHasExplicitTime: false,
                editRecurrenceHasTimeRange: true,
                editRecurrenceTimeRangeStart: timeRange.start,
                editRecurrenceTimeRangeEnd: timeRange.end
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.recurrenceRule == .daily(in: timeRange))
    }

    @Test
    func editSaveTapped_persistsIntervalAvailability() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Water plants",
            interval: 7,
            lastDone: nil,
            emoji: "🪴",
            recurrenceRule: .interval(days: 7),
            scheduleAnchor: makeDate("2026-03-10T06:00:00Z")
        )
        let exactTime = RoutineTimeOfDay(hour: 20, minute: 0)

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Water plants",
                editRoutineEmoji: "🪴",
                editScheduleMode: .fixedInterval,
                editFrequency: .week,
                editFrequencyValue: 1,
                editRecurrenceKind: .intervalDays,
                editRecurrenceHasExplicitTime: true,
                editRecurrenceTimeOfDay: exactTime
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.recurrenceRule == .interval(days: 7, at: exactTime))
    }

    @Test
    func editSaveTapped_persistsGentleIntervalAvailability() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 7,
            lastDone: nil,
            emoji: "📚",
            recurrenceRule: .interval(days: 7),
            scheduleAnchor: makeDate("2026-03-10T06:00:00Z")
        )
        let exactTime = RoutineTimeOfDay(hour: 21, minute: 0)

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Read",
                editRoutineEmoji: "📚",
                editScheduleMode: .softInterval,
                editFrequency: .week,
                editFrequencyValue: 1,
                editRecurrenceKind: .intervalDays,
                editRecurrenceHasExplicitTime: true,
                editRecurrenceTimeOfDay: exactTime
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.scheduleMode == .softInterval)
        #expect(persistedTask.recurrenceRule == .interval(days: 7, at: exactTime))
    }
}
