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
struct SwiftDataModelTests {
    @Test
    func routineTask_defaultsAreInitialized() {
        let task = RoutineTask()
        #expect(task.interval == 1)
        #expect(task.recurrenceRule == .interval(days: 1))
        #expect(!task.id.uuidString.isEmpty)
        #expect(task.lastDone == nil)
        #expect(task.placeID == nil)
        #expect(task.scheduleAnchor == nil)
        #expect(task.pausedAt == nil)
        #expect(task.tags.isEmpty)
        #expect(task.steps.isEmpty)
        #expect(task.checklistItems.isEmpty)
        #expect(task.scheduleMode == .fixedInterval)
        #expect(task.priority == .none)
        #expect(task.importance == .level2)
        #expect(task.urgency == .level2)
        #expect(task.completedStepCount == 0)
        #expect(task.sequenceStartedAt == nil)
        #expect(task.activityState == .idle)
        #expect(task.ongoingSince == nil)
        #expect(task.autoAssumeDailyDone == false)
        #expect(task.estimatedDurationMinutes == nil)
        #expect(task.storyPoints == nil)
    }

    @Test
    func routineTask_tagsAreSanitizedAndDeduplicated() {
        let task = RoutineTask(tags: [" Health ", "health", "deep work", ""])
        #expect(task.tags == ["Health", "deep work"])
    }

    @Test
    func routinePlace_normalizesNameAndClampsRadius() {
        let place = RoutinePlace(name: "  Home  ", latitude: 52.52, longitude: 13.405, radiusMeters: 5)
        #expect(place.name == "Home")
        #expect(place.displayName == "Home")
        #expect(place.radiusMeters == 25)
    }

    @Test
    func routineLog_defaultsAreInitialized() {
        let taskID = UUID()
        let log = RoutineLog(taskID: taskID)
        #expect(log.taskID == taskID)
        #expect(!log.id.uuidString.isEmpty)
        #expect(log.timestamp == nil)
    }

    @Test
    func routineTask_stepsSerializeAndAdvanceSequentially() {
        let firstStepID = UUID()
        let secondStepID = UUID()
        let task = RoutineTask(
            steps: [
                RoutineStep(id: firstStepID, title: "Wash clothes"),
                RoutineStep(id: secondStepID, title: "Hang on the line")
            ]
        )

        #expect(task.steps.map(\.title) == ["Wash clothes", "Hang on the line"])
        #expect(task.nextStepTitle == "Wash clothes")

        let firstAdvance = task.advance(completedAt: makeDate("2026-03-17T10:00:00Z"))
        #expect(firstAdvance == .advancedStep(completedSteps: 1, totalSteps: 2))
        #expect(task.isInProgress)
        #expect(task.nextStepTitle == "Hang on the line")

        let secondAdvance = task.advance(completedAt: makeDate("2026-03-17T11:00:00Z"))
        #expect(secondAdvance == .completedRoutine)
        #expect(task.completedStepCount == 0)
        #expect(task.sequenceStartedAt == nil)
        #expect(task.lastDone == makeDate("2026-03-17T11:00:00Z"))
    }

    @Test
    func routineTask_checklistItemsSerializeAndUpdateIndividually() {
        let breadID = UUID()
        let milkID = UUID()
        let createdAt = makeDate("2026-03-17T10:00:00Z")
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5, createdAt: createdAt)
            ]
        )

        #expect(task.scheduleMode == .derivedFromChecklist)
        #expect(task.checklistItems.map(\.title) == ["Bread", "Milk"])

        let updatedCount = task.markChecklistItemsPurchased([breadID], purchasedAt: makeDate("2026-03-18T12:00:00Z"))
        #expect(updatedCount == 1)
        #expect(task.checklistItems.first(where: { $0.id == breadID })?.lastPurchasedAt == makeDate("2026-03-18T12:00:00Z"))
        #expect(task.checklistItems.first(where: { $0.id == milkID })?.lastPurchasedAt == nil)
        #expect(task.lastDone == makeDate("2026-03-18T12:00:00Z"))
    }

    @Test
    func routineTask_oneOffStripsChecklistAndForcesSingleDayInterval() {
        let completedAt = makeDate("2026-03-18T12:00:00Z")
        let task = RoutineTask(
            steps: [RoutineStep(title: "Buy milk")],
            checklistItems: [RoutineChecklistItem(title: "Milk", intervalDays: 3)],
            scheduleMode: .oneOff,
            interval: 14,
            lastDone: completedAt
        )

        #expect(task.scheduleMode == .oneOff)
        #expect(task.isOneOffTask)
        #expect(task.interval == 1)
        #expect(task.steps.map(\.title) == ["Buy milk"])
        #expect(task.checklistItems.isEmpty)
        #expect(task.scheduleAnchor == completedAt)
    }

    @Test
    func routineTask_completedOneOffDependsOnCompletionState() {
        let completedAt = makeDate("2026-03-18T12:00:00Z")
        let completedTask = RoutineTask(
            scheduleMode: .oneOff,
            interval: 10,
            lastDone: completedAt
        )
        let inProgressTask = RoutineTask(
            steps: [
                RoutineStep(title: "Pack bag"),
                RoutineStep(title: "Leave home")
            ],
            scheduleMode: .oneOff,
            interval: 10,
            lastDone: completedAt,
            completedStepCount: 1,
            sequenceStartedAt: makeDate("2026-03-18T11:00:00Z")
        )

        #expect(completedTask.isCompletedOneOff)
        #expect(!inProgressTask.isCompletedOneOff)
    }

    @Test
    func routineTask_fixedIntervalChecklist_completesOnlyAfterAllItemsAreDone() {
        let breadID = UUID()
        let milkID = UUID()
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 7
        )

        let firstCompletion = task.markChecklistItemCompleted(
            breadID,
            completedAt: makeDate("2026-03-18T12:00:00Z")
        )
        #expect(firstCompletion == .advancedChecklist(completedItems: 1, totalItems: 2))
        #expect(task.completedChecklistItemCount == 1)
        #expect(task.isChecklistInProgress)
        #expect(task.lastDone == nil)

        let finalCompletion = task.markChecklistItemCompleted(
            milkID,
            completedAt: makeDate("2026-03-18T12:05:00Z")
        )
        #expect(finalCompletion == .completedRoutine)
        #expect(task.completedChecklistItemCount == 0)
        #expect(!task.isChecklistInProgress)
        #expect(task.lastDone == makeDate("2026-03-18T12:05:00Z"))
    }

    @Test
    func routineTask_dailyTimeRecurrencePreservesExplicitScheduleRule() {
        let task = RoutineTask(
            name: "Stretch",
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 15)),
            scheduleAnchor: makeDate("2026-03-18T10:00:00Z")
        )

        #expect(task.recurrenceRule == .daily(at: RoutineTimeOfDay(hour: 21, minute: 15)))
        #expect(task.interval == 1)

        _ = task.advance(completedAt: makeDate("2026-03-18T21:30:00Z"))

        #expect(task.lastDone == makeDate("2026-03-18T21:30:00Z"))
        #expect(task.scheduleAnchor == makeDate("2026-03-18T10:00:00Z"))
    }

    @Test
    func routineTask_weeklyAndMonthlyRecurrencePreserveExplicitScheduleRule() {
        let weeklyTask = RoutineTask(
            name: "Review",
            recurrenceRule: .weekly(on: 6, at: RoutineTimeOfDay(hour: 18, minute: 45)),
            scheduleAnchor: makeDate("2026-03-18T10:00:00Z")
        )
        let monthlyTask = RoutineTask(
            name: "Bills",
            recurrenceRule: .monthly(on: 21, at: RoutineTimeOfDay(hour: 18, minute: 45)),
            scheduleAnchor: makeDate("2026-03-18T10:00:00Z")
        )

        #expect(weeklyTask.recurrenceRule == .weekly(on: 6, at: RoutineTimeOfDay(hour: 18, minute: 45)))
        #expect(monthlyTask.recurrenceRule == .monthly(on: 21, at: RoutineTimeOfDay(hour: 18, minute: 45)))
    }

    @Test
    func routineTask_softIntervalSupportsOngoingLifecycle() {
        let task = RoutineTask(
            name: "Travel",
            scheduleMode: .softInterval,
            recurrenceRule: .interval(days: 180),
            scheduleAnchor: makeDate("2026-03-18T10:00:00Z")
        )

        task.startOngoing(at: makeDate("2026-04-10T08:00:00Z"))

        #expect(task.isOngoing)
        #expect(task.ongoingSince == makeDate("2026-04-10T08:00:00Z"))

        task.finishOngoing(at: makeDate("2026-04-18T19:00:00Z"))

        #expect(!task.isOngoing)
        #expect(task.ongoingSince == nil)
        #expect(task.lastDone == makeDate("2026-04-18T19:00:00Z"))
    }

    @Test
    func routineTask_sanitizesNotesAndKeepsDeadlineOnlyForTodos() {
        let todoDeadline = makeDate("2026-03-21T09:00:00Z")
        let todo = RoutineTask(
            notes: "  pick whole milk  ",
            deadline: todoDeadline,
            scheduleMode: .oneOff
        )
        let routine = RoutineTask(
            notes: " \n ",
            deadline: todoDeadline,
            scheduleMode: .fixedInterval
        )

        #expect(todo.notes == "pick whole milk")
        #expect(todo.deadline == todoDeadline)
        #expect(routine.notes == nil)
        #expect(routine.deadline == nil)
    }

    @Test
    func routineTask_persistsPriority() {
        let task = RoutineTask(priority: .high)
        #expect(task.priority == .high)

        task.priority = .urgent
        #expect(task.priority == .urgent)
    }

    @Test
    func routineTask_persistsImportanceAndUrgency() {
        let task = RoutineTask(importance: .level1, urgency: .level4)
        #expect(task.importance == .level1)
        #expect(task.urgency == .level4)
        #expect(task.derivedPriorityFromMatrix == .high)

        task.importance = .level4
        task.urgency = .level4

        #expect(task.importance == .level4)
        #expect(task.urgency == .level4)
        #expect(task.derivedPriorityFromMatrix == .urgent)
    }

    @Test
    func routineTask_persistsPressure() {
        let task = RoutineTask(pressure: .medium)
        #expect(task.pressure == .medium)

        task.pressure = .high
        #expect(task.pressure == .high)
        #expect(task.pressureUpdatedAt != nil)

        task.pressure = .none
        #expect(task.pressure == .none)
        #expect(task.pressureUpdatedAt == nil)
    }

    @Test
    func routineTask_sanitizesLinksAndBuildsResolvedURL() {
        let task = RoutineTask(link: " example.com/docs ")
        let invalid = RoutineTask(link: "not a valid url")

        #expect(task.link == "https://example.com/docs")
        #expect(task.resolvedLinkURL?.absoluteString == "https://example.com/docs")
        #expect(invalid.link == nil)
        #expect(invalid.resolvedLinkURL == nil)
    }

    @Test
    func routineTaskRelationshipCandidate_from_resolvesStatuses() {
        let referenceDate = makeDate("2026-03-20T10:00:00Z")
        let calendar = makeTestCalendar()

        let doneToday = RoutineTask(name: "Done Today", lastDone: referenceDate)
        let completedTodo = RoutineTask(name: "Completed Todo", scheduleMode: .oneOff, lastDone: referenceDate)
        let canceledTodo = RoutineTask(name: "Canceled Todo", scheduleMode: .oneOff, canceledAt: referenceDate)
        let paused = RoutineTask(name: "Paused", interval: 2, pausedAt: referenceDate)
        let pendingTodo = RoutineTask(name: "Pending Todo", scheduleMode: .oneOff)
        let overdue = RoutineTask(
            name: "Overdue",
            interval: 2,
            scheduleAnchor: makeDate("2026-03-15T10:00:00Z")
        )
        let dueToday = RoutineTask(
            name: "Due Today",
            interval: 2,
            scheduleAnchor: makeDate("2026-03-18T10:00:00Z")
        )
        let onTrack = RoutineTask(
            name: "On Track",
            interval: 2,
            scheduleAnchor: makeDate("2026-03-19T10:00:00Z")
        )

        let candidates = RoutineTaskRelationshipCandidate.from(
            [doneToday, completedTodo, canceledTodo, paused, pendingTodo, overdue, dueToday, onTrack],
            referenceDate: referenceDate,
            calendar: calendar
        )
        let statusByName = Dictionary(uniqueKeysWithValues: candidates.map { ($0.name, $0.status) })

        #expect(statusByName["Done Today"] == .doneToday)
        #expect(statusByName["Completed Todo"] == .completedOneOff)
        #expect(statusByName["Canceled Todo"] == .canceledOneOff)
        #expect(statusByName["Paused"] == .paused)
        #expect(statusByName["Pending Todo"] == .pendingTodo)
        #expect(statusByName["Overdue"] == .overdue(days: 3))
        #expect(statusByName["Due Today"] == .dueToday)
        #expect(statusByName["On Track"] == .onTrack)
    }

    @Test
    func routineTaskResolvedRelationships_preserveCandidateStatuses() {
        let referenceDate = makeDate("2026-03-20T10:00:00Z")
        let calendar = makeTestCalendar()
        let currentTaskID = UUID()
        let directTaskID = UUID()
        let inverseTaskID = UUID()

        let currentTask = RoutineTask(
            id: currentTaskID,
            name: "Current",
            relationships: [RoutineTaskRelationship(targetTaskID: directTaskID, kind: .blocks)]
        )
        let directTask = RoutineTask(
            id: directTaskID,
            name: "Direct",
            pausedAt: referenceDate
        )
        let inverseTask = RoutineTask(
            id: inverseTaskID,
            name: "Inverse",
            relationships: [RoutineTaskRelationship(targetTaskID: currentTaskID, kind: .blocks)],
            scheduleMode: .oneOff
        )

        let candidates = RoutineTaskRelationshipCandidate.from(
            [directTask, inverseTask],
            referenceDate: referenceDate,
            calendar: calendar
        )
        let resolved = RoutineTask.resolvedRelationships(for: currentTask, within: candidates)

        #expect(resolved == [
            RoutineTaskResolvedRelationship(
                taskID: inverseTaskID,
                taskName: "Inverse",
                taskEmoji: "✨",
                kind: .blockedBy,
                status: .pendingTodo
            ),
            RoutineTaskResolvedRelationship(
                taskID: directTaskID,
                taskName: "Direct",
                taskEmoji: "✨",
                kind: .blocks,
                status: .paused
            )
        ])
    }

    // MARK: - createdAt

    @Test
    func routineTask_createdAtIsSetByInit() throws {
        let before = Date()
        let task = RoutineTask(name: "Run")
        let after = Date()
        let createdAt = try #require(task.createdAt)
        #expect(createdAt >= before)
        #expect(createdAt <= after)
    }

    @Test
    func routineTask_createdAtCanBeExplicitlyNil() {
        let task = RoutineTask(name: "Run", createdAt: nil)
        #expect(task.createdAt == nil)
    }

    @Test
    func routineTask_createdAtCanBeExplicitlySet() {
        let date = makeDate("2025-01-15T09:00:00Z")
        let task = RoutineTask(name: "Run", createdAt: date)
        #expect(task.createdAt == date)
    }

    @Test
    func routineTask_createdAtPersistsAfterSaveAndFetch() async throws {
        let context = makeInMemoryContext()
        let date = makeDate("2025-06-01T08:00:00Z")
        let task = RoutineTask(name: "Meditate", createdAt: date)
        context.insert(task)
        try context.save()

        let fetched = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(fetched.createdAt == date)
    }

    @Test
    func routineTask_nilCreatedAtPersistsAfterSaveAndFetch() async throws {
        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Legacy task", createdAt: nil)
        context.insert(task)
        try context.save()

        let fetched = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(fetched.createdAt == nil)
    }
}
