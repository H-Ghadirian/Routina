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
        #expect(task.recurrenceStorageVersion == 1)
        #expect(task.recurrenceKindRawValue == RoutineRecurrenceRule.Kind.intervalDays.rawValue)
        #expect(task.recurrenceRuleStorage.isEmpty)
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
        #expect(task.isAllDay == false)
        #expect(task.autoAssumeDailyDone == false)
        #expect(task.estimatedDurationMinutes == nil)
        #expect(task.storyPoints == nil)
        #expect(task.focusModeEnabled == false)
        #expect(task.voiceNote == nil)
        #expect(task.hasVoiceNote == false)
    }

    @Test
    func routineTask_storesVoiceNoteAndCopiesItDetached() {
        let data = Data([0x01, 0x02, 0x03])
        let createdAt = Date(timeIntervalSince1970: 42)
        let task = RoutineTask(
            name: "Practice",
            voiceNoteData: data,
            voiceNoteDurationSeconds: 12.4,
            voiceNoteCreatedAt: createdAt
        )

        #expect(task.hasVoiceNote)
        #expect(task.voiceNote?.data == data)
        #expect(task.voiceNote?.durationSeconds == 12.4)
        #expect(task.voiceNote?.createdAt == createdAt)

        let copy = task.detachedCopy()
        #expect(copy.voiceNote == task.voiceNote)
        #expect(copy.hasVoiceNote)
    }

    @Test
    func routineTask_storesAllDayFlagForTasksAndCopiesItDetached() {
        let deadline = Date(timeIntervalSince1970: 1_780_000_000)
        let todo = RoutineTask(
            name: "Conference",
            deadline: deadline,
            isAllDay: true,
            scheduleMode: .oneOff
        )
        let routine = RoutineTask(
            name: "Daily practice",
            deadline: deadline,
            isAllDay: true,
            scheduleMode: .fixedInterval
        )

        #expect(todo.isAllDay)
        #expect(todo.detachedCopy().isAllDay)
        #expect(routine.deadline == nil)
        #expect(routine.isAllDay)
        #expect(routine.detachedCopy().isAllDay)
    }

    @Test
    func routineTask_storesRoutineDurationIndependentFromAllDay() {
        let routine = RoutineTask(
            name: "Travel",
            isAllDay: false,
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval
        )
        let allDayRoutine = RoutineTask(
            name: "Retreat",
            isAllDay: true,
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval
        )
        let todo = RoutineTask(
            name: "Conference",
            isAllDay: true,
            routineDurationMode: .multiDay,
            scheduleMode: .oneOff
        )

        #expect(routine.routineDurationMode == .multiDay)
        #expect(routine.isMultiDayRoutine)
        #expect(routine.usesOngoingLifecycle)
        #expect(routine.detachedCopy().routineDurationMode == .multiDay)
        #expect(allDayRoutine.routineDurationMode == .multiDay)
        #expect(allDayRoutine.isMultiDayRoutine)
        #expect(todo.routineDurationMode == .oneDay)
        #expect(!todo.isMultiDayRoutine)

        routine.scheduleMode = .oneOff
        #expect(routine.routineDurationMode == .oneDay)
        #expect(!routine.isMultiDayRoutine)
    }

    @Test
    func routineTask_normalizesPlannedDateAndCopiesItDetached() {
        let plannedDate = makeDate("2026-06-10T15:45:00Z")
        let expectedDate = Calendar.current.startOfDay(for: plannedDate)
        let task = RoutineTask(
            name: "Draft plan",
            plannedDate: plannedDate
        )

        #expect(task.plannedDate == expectedDate)
        #expect(RoutineTask.normalizedPlannedDate(plannedDate) == expectedDate)
        #expect(task.detachedCopy().plannedDate == expectedDate)
    }

    @Test
    func routineEvent_sanitizesTextTagsAndCopiesDetached() {
        let startedAt = Date(timeIntervalSince1970: 1_780_000_000)
        let endedAt = startedAt.addingTimeInterval(2 * 60 * 60)
        let reminderAt = startedAt.addingTimeInterval(-15 * 60)
        let event = RoutineEvent(
            title: "  Sick day  ",
            notes: "  Fever and rest  ",
            emoji: " 🤒 ",
            tags: [" Health ", "health", "Recovery"],
            isAllDay: false,
            startedAt: startedAt,
            endedAt: endedAt,
            reminderAt: reminderAt,
            createdAt: startedAt,
            updatedAt: endedAt
        )

        #expect(event.title == "Sick day")
        #expect(event.notes == "Fever and rest")
        #expect(event.emoji == "🤒")
        #expect(event.displayTitle == "Sick day")
        #expect(event.displayEmoji == "🤒")
        #expect(event.tags == ["Health", "Recovery"])
        #expect(event.endedAt == endedAt)
        #expect(event.reminderAt == reminderAt)

        let copy = event.detachedCopy()
        #expect(copy.id == event.id)
        #expect(copy.title == event.title)
        #expect(copy.tags == event.tags)
        #expect(copy.isAllDay == false)
        #expect(copy.startedAt == startedAt)
        #expect(copy.endedAt == endedAt)
        #expect(copy.reminderAt == reminderAt)
    }

    @Test
    func routineScheduleMode_composesScheduleBehaviorAndFormat() {
        #expect(RoutineScheduleMode.routineMode(behavior: .fixed, format: .standard) == .fixedInterval)
        #expect(RoutineScheduleMode.routineMode(behavior: .soft, format: .standard) == .softInterval)
        #expect(RoutineScheduleMode.routineMode(behavior: .fixed, format: .checklist) == .fixedIntervalChecklist)
        #expect(RoutineScheduleMode.routineMode(behavior: .soft, format: .checklist) == .softIntervalChecklist)
        #expect(RoutineScheduleMode.routineMode(behavior: .fixed, format: .runout) == .derivedFromChecklist)
        #expect(RoutineScheduleMode.routineMode(behavior: .soft, format: .runout) == .softDerivedFromChecklist)

        #expect(RoutineScheduleMode.softIntervalChecklist.scheduleBehavior == .soft)
        #expect(RoutineScheduleMode.softIntervalChecklist.routineFormat == .checklist)
        #expect(RoutineScheduleMode.softIntervalChecklist.routineFinishMode == .checklist)
        #expect(RoutineScheduleMode.softIntervalChecklist.checklistTimingMode == .together)
        #expect(RoutineScheduleMode.softDerivedFromChecklist.scheduleBehavior == .soft)
        #expect(RoutineScheduleMode.softDerivedFromChecklist.routineFormat == .runout)
        #expect(RoutineScheduleMode.softDerivedFromChecklist.routineFinishMode == .checklist)
        #expect(RoutineScheduleMode.softDerivedFromChecklist.checklistTimingMode == .runout)
        #expect(RoutineScheduleMode.fixedInterval.routineFinishMode == .standard)
        #expect(RoutineScheduleMode.derivedFromChecklist.replacingRoutineFinishMode(.standard) == .fixedInterval)
        #expect(RoutineScheduleMode.derivedFromChecklist.replacingRoutineFinishMode(.checklist) == .derivedFromChecklist)
        #expect(RoutineScheduleMode.fixedInterval.replacingRoutineFinishMode(.checklist) == .fixedIntervalChecklist)
        #expect(RoutineScheduleMode.derivedFromChecklist.replacingChecklistTimingMode(.together) == .fixedIntervalChecklist)
        #expect(RoutineScheduleMode.softIntervalChecklist.replacingChecklistTimingMode(.runout) == .softDerivedFromChecklist)

        #expect(RoutineScheduleBehavior.fixed.rawValue == "Due")
        #expect(RoutineScheduleBehavior.soft.rawValue == "Gentle")
        #expect(RoutineScheduleBehavior.fixed.explanation == "Due means this can become due or overdue.")
        #expect(RoutineScheduleBehavior.soft.explanation == "Gentle keeps it visible and nudges you without overdue pressure.")
        #expect(RoutineScheduleBehavior.fixed.rowPreviewBadges.map(\.title) == ["Today", "Overdue 2d"])
        #expect(RoutineScheduleBehavior.soft.rowPreviewBadges.map(\.title) == ["Ready to Do", "Gentle nudge"])
        #expect(RoutineScheduleBehavior.fixed.rowPreviewDescription == "Rows show Today, then Overdue if not completed.")
        #expect(RoutineScheduleBehavior.soft.rowPreviewDescription == "Rows show Ready to Do or Gentle nudge, never Overdue.")
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
        let createdAt = makeDate("2026-03-10T10:00:00Z")
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5, createdAt: createdAt)
            ]
        )

        #expect(task.scheduleMode == .derivedFromChecklist)
        #expect(task.checklistItems.map(\.title) == ["Bread", "Milk"])

        let update = task.markChecklistItemsDone(
            [breadID],
            doneAt: makeDate("2026-03-18T12:00:00Z"),
            calendar: makeTestCalendar()
        )
        #expect(update.updatedItemCount == 1)
        #expect(!update.didCompleteRoutine)
        #expect(task.checklistItems.first(where: { $0.id == breadID })?.lastPurchasedAt == makeDate("2026-03-18T12:00:00Z"))
        #expect(task.checklistItems.first(where: { $0.id == milkID })?.lastPurchasedAt == nil)
        #expect(task.lastDone == nil)
    }

    @Test
    func routineTask_checklistRunoutCompletionOnlyRecordsWhenAllDueItemsReset() {
        let breadID = UUID()
        let milkID = UUID()
        let createdAt = makeDate("2026-03-10T10:00:00Z")
        let doneAt = makeDate("2026-03-18T12:00:00Z")
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5, createdAt: createdAt)
            ]
        )

        let update = task.markChecklistItemsDone([breadID, milkID], doneAt: doneAt, calendar: calendar)

        #expect(update == RoutineTask.ChecklistRunoutUpdate(updatedItemCount: 2, didCompleteRoutine: true))
        #expect(task.lastDone == doneAt)
        #expect(task.dueChecklistItems(referenceDate: doneAt, calendar: calendar).isEmpty)
    }

    @Test
    func routineTask_extendChecklistRunoutAddsOneDayToCurrentDueDate() {
        let breadID = UUID()
        let createdAt = makeDate("2026-03-10T10:00:00Z")
        let referenceDate = makeDate("2026-03-14T12:00:00Z")
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: createdAt)
            ]
        )

        let updatedCount = task.extendChecklistItemsRunout(
            [breadID],
            referenceDate: referenceDate,
            calendar: calendar
        )
        let item = task.checklistItems.first { $0.id == breadID }

        #expect(updatedCount == 1)
        #expect(item?.lastPurchasedAt == makeDate("2026-03-11T10:00:00Z"))
        #expect(item.map { RoutineDateMath.dueDate(for: $0, referenceDate: referenceDate, calendar: calendar) } == makeDate("2026-03-14T10:00:00Z"))
        #expect(task.lastDone == nil)
    }

    @Test
    func routineTask_undoChecklistRunoutDoneRestoresPreviousItemState() {
        let breadID = UUID()
        let createdAt = makeDate("2026-03-10T10:00:00Z")
        let previousDoneAt = makeDate("2026-03-12T10:00:00Z")
        let doneAt = makeDate("2026-03-18T12:00:00Z")
        let previousTaskDoneAt = makeDate("2026-03-11T09:00:00Z")
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(
                    id: breadID,
                    title: "Bread",
                    intervalDays: 3,
                    lastPurchasedAt: previousDoneAt,
                    createdAt: createdAt
                )
            ],
            lastDone: previousTaskDoneAt,
            scheduleAnchor: previousTaskDoneAt
        )

        let doneUpdate = task.markChecklistItemsDone([breadID], doneAt: doneAt, calendar: calendar)
        let undoUpdate = task.undoChecklistItemRunoutDone(breadID, referenceDate: doneAt, calendar: calendar)
        let item = task.checklistItems.first { $0.id == breadID }

        #expect(doneUpdate.didCompleteRoutine)
        #expect(undoUpdate == RoutineTask.ChecklistRunoutUndoUpdate(restoredItemCount: 1, removedCompletionAt: doneAt))
        #expect(item?.lastPurchasedAt == previousDoneAt)
        #expect(item?.undoLastPurchasedAt == nil)
        #expect(task.lastDone == previousTaskDoneAt)
        #expect(task.scheduleAnchor == previousTaskDoneAt)
    }

    @Test
    func routineTask_undoEarlierRunoutItemRemovesLaterRoutineCompletion() {
        let breadID = UUID()
        let milkID = UUID()
        let createdAt = makeDate("2026-03-10T10:00:00Z")
        let previousTaskDoneAt = makeDate("2026-03-11T09:00:00Z")
        let breadDoneAt = makeDate("2026-03-18T12:00:00Z")
        let milkDoneAt = makeDate("2026-03-18T12:05:00Z")
        let calendar = makeTestCalendar()
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5, createdAt: createdAt)
            ],
            lastDone: previousTaskDoneAt,
            scheduleAnchor: previousTaskDoneAt
        )

        let breadUpdate = task.markChecklistItemsDone([breadID], doneAt: breadDoneAt, calendar: calendar)
        let milkUpdate = task.markChecklistItemsDone([milkID], doneAt: milkDoneAt, calendar: calendar)
        let undoUpdate = task.undoChecklistItemRunoutDone(breadID, referenceDate: milkDoneAt, calendar: calendar)

        #expect(!breadUpdate.didCompleteRoutine)
        #expect(milkUpdate.didCompleteRoutine)
        #expect(undoUpdate == RoutineTask.ChecklistRunoutUndoUpdate(restoredItemCount: 1, removedCompletionAt: milkDoneAt))
        #expect(task.checklistItems.first(where: { $0.id == breadID })?.lastPurchasedAt == nil)
        #expect(task.checklistItems.first(where: { $0.id == milkID })?.lastPurchasedAt == milkDoneAt)
        #expect(task.lastDone == previousTaskDoneAt)
        #expect(task.scheduleAnchor == previousTaskDoneAt)
    }

    @Test
    func routineTask_oneOffKeepsChecklistAndForcesSingleDayInterval() {
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
        #expect(task.checklistItems.map(\.title) == ["Milk"])
        #expect(task.scheduleAnchor == completedAt)
    }

    @Test
    func routineTask_oneOffKeepsAvailabilityTimingWhileForcingSingleDayInterval() {
        let exactTime = RoutineTimeOfDay(hour: 20, minute: 0)
        let task = RoutineTask(
            name: "Call landlord",
            scheduleMode: .oneOff,
            interval: 14,
            recurrenceRule: .interval(days: 14, at: exactTime)
        )

        #expect(task.scheduleMode == .oneOff)
        #expect(task.interval == 1)
        #expect(task.recurrenceRule == .interval(days: 1, at: exactTime))
    }

    @Test
    func routineTask_optionalChecklistProgressCanBeToggled() {
        let itemID = UUID()
        let task = RoutineTask(
            checklistItems: [RoutineChecklistItem(id: itemID, title: "Book room", intervalDays: 1)],
            scheduleMode: .fixedInterval
        )

        #expect(task.supportsOptionalChecklistProgress)
        #expect(task.markOptionalChecklistItemCompleted(itemID))
        #expect(task.isChecklistItemCompleted(itemID))
        #expect(task.unmarkChecklistItemCompleted(itemID))
        #expect(!task.isChecklistItemCompleted(itemID))
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
        #expect(task.recurrenceKindRawValue == RoutineRecurrenceRule.Kind.dailyTime.rawValue)
        #expect(task.recurrenceTimeOfDayHour == 21)
        #expect(task.recurrenceTimeOfDayMinute == 15)
        #expect(task.recurrenceRuleStorage.isEmpty)

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
        #expect(weeklyTask.recurrenceWeekday == 6)
        #expect(monthlyTask.recurrenceDayOfMonth == 21)
    }

    @Test
    func routineTask_timeRangeRecurrencePreservesScheduleRule() {
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let task = RoutineTask(
            name: "Breakfast",
            recurrenceRule: .daily(in: timeRange),
            scheduleAnchor: makeDate("2026-03-18T06:00:00Z")
        )

        #expect(task.recurrenceRule == .daily(in: timeRange))
        #expect(task.recurrenceRule.displayText() == "Every day from \(timeRange.formatted())")
        #expect(task.recurrenceTimeRangeStartHour == 7)
        #expect(task.recurrenceTimeRangeStartMinute == 0)
        #expect(task.recurrenceTimeRangeEndHour == 10)
        #expect(task.recurrenceTimeRangeEndMinute == 0)
        #expect(task.recurrenceRuleStorage.isEmpty)
    }

    @Test
    func routineTask_intervalRecurrencePreservesAvailability() {
        let exactTime = RoutineTimeOfDay(hour: 20, minute: 0)
        let exactTask = RoutineTask(
            name: "Water plants",
            recurrenceRule: .interval(days: 7, at: exactTime),
            scheduleAnchor: makeDate("2026-03-18T10:00:00Z")
        )
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let rangeTask = RoutineTask(
            name: "Breakfast supplies",
            recurrenceRule: .interval(days: 3, timeRange: timeRange),
            scheduleAnchor: makeDate("2026-03-18T06:00:00Z")
        )

        #expect(exactTask.recurrenceRule == .interval(days: 7, at: exactTime))
        #expect(exactTask.recurrenceRule.displayText() == "Every week at \(exactTime.formatted())")
        #expect(exactTask.recurrenceTimeOfDayHour == 20)
        #expect(exactTask.recurrenceTimeOfDayMinute == 0)
        #expect(rangeTask.recurrenceRule == .interval(days: 3, timeRange: timeRange))
        #expect(rangeTask.recurrenceRule.displayText() == "Every 3 days from \(timeRange.formatted())")
        #expect(rangeTask.recurrenceTimeRangeStartHour == 7)
        #expect(rangeTask.recurrenceTimeRangeEndHour == 10)
    }

    @Test
    func routineTask_monthlyDisplayTextUsesLastDayFallbackCopy() {
        let exactTime = RoutineTimeOfDay(hour: 20, minute: 0)

        #expect(RoutineRecurrenceRule.monthly(on: 31).displayText() == "Every last day of the month")
        #expect(RoutineRecurrenceRule.monthly(on: 31, at: exactTime).displayText() == "Every last day of the month at \(exactTime.formatted())")
        #expect(RoutineRecurrenceRule.monthly(on: 30).displayText() == "Every 30th; shorter months use last day")
        #expect(RoutineRecurrenceRule.monthly(on: [1, 15, 31]).displayText() == "Every 1st, 15th, and last day of the month; shorter months use last day")
    }

    @Test
    func routineTask_multiDayCalendarRecurrencePreservesSelectionsInStorage() {
        let weeklyRule = RoutineRecurrenceRule.weekly(on: [2, 4, 6])
        let monthlyRule = RoutineRecurrenceRule.monthly(on: [1, 15, 31])

        let weeklyTask = RoutineTask(recurrenceRule: weeklyRule)
        let monthlyTask = RoutineTask(recurrenceRule: monthlyRule)

        #expect(weeklyTask.recurrenceRule == weeklyRule)
        #expect(monthlyTask.recurrenceRule == monthlyRule)
        #expect(weeklyTask.recurrenceWeekday == 2)
        #expect(monthlyTask.recurrenceDayOfMonth == 1)
        #expect(!weeklyTask.recurrenceRuleStorage.isEmpty)
        #expect(!monthlyTask.recurrenceRuleStorage.isEmpty)
    }

    @Test
    func routineTask_migratesLegacyJSONRecurrenceRuleToSwiftDataColumns() {
        let legacyRule = RoutineRecurrenceRule.weekly(
            on: 6,
            at: RoutineTimeOfDay(hour: 18, minute: 45)
        )
        let task = RoutineTask(interval: 7)
        task.recurrenceStorageVersion = 0
        task.recurrenceKindRawValue = RoutineRecurrenceRule.Kind.intervalDays.rawValue
        task.recurrenceTimeOfDayHour = nil
        task.recurrenceTimeOfDayMinute = nil
        task.recurrenceWeekday = nil
        task.recurrenceRuleStorage = RoutineRecurrenceRuleStorage.serialize(legacyRule)

        #expect(task.recurrenceRule == legacyRule)
        #expect(task.migrateLegacyRecurrenceRuleStorageIfNeeded())
        #expect(task.recurrenceRule == legacyRule)
        #expect(task.recurrenceStorageVersion == 1)
        #expect(task.recurrenceKindRawValue == RoutineRecurrenceRule.Kind.weekly.rawValue)
        #expect(task.recurrenceTimeOfDayHour == 18)
        #expect(task.recurrenceTimeOfDayMinute == 45)
        #expect(task.recurrenceWeekday == 6)
        #expect(task.recurrenceRuleStorage.isEmpty)
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
        let multiLinkTask = RoutineTask(
            links: [
                "example.com/docs",
                " https://example.com/pricing ",
                "ftp://example.com",
                "EXAMPLE.com/docs"
            ]
        )

        #expect(task.link == "https://example.com/docs")
        #expect(task.links == ["https://example.com/docs"])
        #expect(task.resolvedLinkURL?.absoluteString == "https://example.com/docs")
        #expect(invalid.link == nil)
        #expect(invalid.links.isEmpty)
        #expect(invalid.resolvedLinkURL == nil)
        #expect(multiLinkTask.link == "https://example.com/docs")
        #expect(multiLinkTask.links == ["https://example.com/docs", "https://example.com/pricing"])
        #expect(multiLinkTask.resolvedLinkURLs.map(\.url.absoluteString) == [
            "https://example.com/docs",
            "https://example.com/pricing"
        ])
    }

    @Test
    func routineTask_preservesTitledLinks() {
        let task = RoutineTask()
        task.linkItems = [
            RoutineTaskLink(title: "Project Brief", url: " example.com/brief "),
            RoutineTaskLink(title: "Duplicate", url: "https://example.com/brief"),
            RoutineTaskLink(title: nil, url: "example.com/raw")
        ]

        #expect(task.link == "https://example.com/brief")
        #expect(task.links == ["https://example.com/brief", "https://example.com/raw"])
        #expect(task.linkItems == [
            RoutineTaskLink(title: "Project Brief", url: "https://example.com/brief"),
            RoutineTaskLink(title: nil, url: "https://example.com/raw")
        ])
        #expect(task.resolvedLinkURLs.map(\.text) == ["Project Brief", "https://example.com/raw"])
        #expect(RoutineTaskLinkStorage.deserializeItems(task.linksStorage) == task.linkItems)
    }

    @Test
    func routineTask_sanitizesEventIDsAndCopiesThem() {
        let firstEventID = UUID()
        let secondEventID = UUID()
        let task = RoutineTask(eventIDs: [firstEventID, secondEventID, firstEventID])

        #expect(task.eventIDs == [firstEventID, secondEventID])

        task.eventIDs = [secondEventID, secondEventID, firstEventID]
        #expect(task.eventIDs == [secondEventID, firstEventID])

        let copy = task.detachedCopy()
        #expect(copy.eventIDs == [secondEventID, firstEventID])
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
