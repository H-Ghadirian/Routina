import Foundation
import SwiftUI
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskFormPresentationTests {
    @Test
    func scheduleAndDescriptionCopyMatchTaskFormModes() {
        let fixed = presentation(scheduleMode: .fixedIntervalChecklist)
        let gentle = presentation(scheduleMode: .softInterval)
        let runout = presentation(scheduleMode: .derivedFromChecklist)
        let oneOff = presentation(taskType: .todo, scheduleMode: .oneOff)

        #expect(fixed.isStepBasedMode == false)
        #expect(fixed.showsRepeatControls)
        #expect(fixed.scheduleModeDescription == "One scheduled routine that finishes after every checklist item is done.")
        #expect(fixed.checklistSectionDescription(includesDerivedChecklistDueDetail: false) == "The routine is done when every checklist item is completed.")
        #expect(runout.showsRepeatControls)
        #expect(gentle.showsRepeatControls)

        #expect(oneOff.isStepBasedMode)
        #expect(oneOff.showsRepeatControls == false)
        #expect(oneOff.notesHelpText == "Capture extra context, links, or reminders for this todo.")
        #expect(oneOff.checklistSectionDescription(includesDerivedChecklistDueDetail: false) == "Use checklist items for parts you want to tick off before finishing the todo.")
    }

    @Test
    func goalPlaceAndPriorityTextAreSharedAcrossPlatforms() {
        let value = presentation(
            importance: .level4,
            urgency: .level3,
            hasAvailableTags: true,
            hasAvailableGoals: false,
            goalDraft: " , Health, ",
            selectedPlaceName: "Gym"
        )

        #expect(value.canAddGoalDraft)
        #expect(value.placeSelectionDescription == "Show this task when you are at Gym.")
        #expect(value.tagSectionHelpText == "Separate multiple tags with commas.")
        #expect(value.goalSectionHelpText == "Press return or Add. Separate multiple goals with commas.")
        #expect(value.linkHelpText == "Add as many websites as you need. URLs without a scheme will use https.")
        #expect(value.importanceUrgencyDescription(includesDerivedPriority: true) == "Critical importance and high urgency map to high priority for sorting.")
        #expect(value.importanceUrgencyDescription(includesDerivedPriority: true, priority: .urgent) == "Critical importance and high urgency map to urgent priority for sorting.")
        #expect(value.importanceUrgencyDescription(includesDerivedPriority: false) == "Critical importance and high urgency.")
    }

    @Test
    func recurrenceAndQuantityLabelsStayConsistent() {
        let weekly = presentation(
            recurrenceHasExplicitTime: false,
            recurrenceWeekday: 2,
            recurrenceDayOfMonth: 33
        )
        let monthly = presentation(
            recurrenceHasExplicitTime: true,
            recurrenceDayOfMonth: 11
        )
        let weeklyWindow = presentation(
            recurrenceHasTimeRange: true,
            recurrenceWeekday: 2
        )
        let weekdaySymbols = Calendar.current.weekdaySymbols

        #expect(TaskFormPresentation.weekdayName(for: 99) == weekdaySymbols.last)
        #expect(TaskFormPresentation.ordinalDay(33) == "31st")
        #expect(TaskFormPresentation.monthDayControlLabel(for: 31) == "Last day of each month")
        #expect(TaskFormPresentation.monthDayControlLabel(for: 30) == "Day 30, or last day in shorter months")
        #expect(TaskFormPresentation.monthDayControlLabel(for: 11) == "Day 11 of each month")
        #expect(TaskFormPresentation.monthDayRepeatLabel(for: 31) == "Every last day of the month")
        #expect(TaskFormPresentation.weekdayListText(for: [2, 4, 6]) == "\(weekdaySymbols[1]), \(weekdaySymbols[3]), and \(weekdaySymbols[5])")
        #expect(TaskFormPresentation.monthDayRepeatLabel(for: [1, 15, 31]) == "Every 1st, 15th, and last day")
        #expect(weekly.recurrencePatternDescription(includesOptionalExactTimeDetail: false) == "Repeat after a fixed number of days, weeks, or months, with optional timing.")
        #expect(weekly.intervalRecurrenceTimeHelpText(exactTimeText: "8:00 PM", timeRangeText: "7:00 AM to 10:00 AM") == "Available any time once the interval has passed.")
        #expect(presentation(recurrenceKind: .intervalDays, recurrenceHasExplicitTime: true).intervalRecurrenceTimeHelpText(exactTimeText: "8:00 PM", timeRangeText: "7:00 AM to 10:00 AM") == "Available after the interval, at 8:00 PM.")
        #expect(presentation(recurrenceKind: .dailyTime).dailyRecurrenceTimeHelpText(exactTimeText: "8:00 PM", timeRangeText: "7:00 AM to 10:00 AM") == "Due every day, any time.")
        #expect(presentation(recurrenceKind: .weekly).recurrencePatternDescription(includesOptionalExactTimeDetail: false) == "Repeat on the same weekday each week.")
        #expect(presentation(recurrenceKind: .monthlyDay).recurrencePatternDescription(includesOptionalExactTimeDetail: false) == "Repeat on the same calendar day each month.")
        #expect(TaskFormPresentation.stepperLabel(unit: .week, value: 1) == "Every week")
        #expect(TaskFormPresentation.stepperLabel(unit: .month, value: 3) == "Every 3 months")
        #expect(TaskFormPresentation.checklistIntervalLabel(for: 2) == "Runs out in 2 days")
        #expect(TaskFormPresentation.estimatedDurationLabel(for: 125) == "2 hours 5 minutes")
        #expect(TaskFormPresentation.storyPointsLabel(for: 1) == "1 story point")
        #expect(weekly.weeklyRecurrenceTimeHelpText() == "Optional. Leave this off to keep the routine due any time on \(weekdaySymbols[1]).")
        #expect(monthly.monthlyRecurrenceTimeHelpText(explicitTimeText: "9:30 AM") == "Due on the 11th of each month at 9:30 AM.")
        #expect(presentation(recurrenceDayOfMonth: 31).monthlyRecurrenceSummary == "Due on the last day of each month.")
        #expect(presentation(recurrenceDayOfMonth: 30).monthlyRecurrenceSummary == "Due on the 30th; shorter months use their last day.")
        #expect(presentation(recurrenceHasExplicitTime: true, recurrenceDayOfMonth: 31).monthlyRecurrenceTimeHelpText(explicitTimeText: "9:30 AM") == "Due on the last day of each month at 9:30 AM.")
        #expect(weeklyWindow.weeklyRecurrenceTimeHelpText(timeRangeText: "7:00 AM to 10:00 AM") == "Due every \(weekdaySymbols[1]) from 7:00 AM to 10:00 AM.")
        #expect(presentation(recurrenceKind: .weekly, recurrenceWeekdays: [2, 4, 6]).weeklyRecurrenceSummary == "Due every \(weekdaySymbols[1]), \(weekdaySymbols[3]), and \(weekdaySymbols[5]).")
        #expect(presentation(recurrenceKind: .monthlyDay, recurrenceDaysOfMonth: [1, 15, 31]).monthlyRecurrenceSummary == "Due on the 1st, 15th, and last day of each month; shorter months use their last day.")
    }

    @Test
    func availabilityModesMatchPersistedTaskTypeSupport() {
        #expect(TaskFormTimingMode.cases(for: .todo) == [.none, .allDay, .exact, .range])
        #expect(TaskFormTimingMode.cases(for: .routine) == [.none, .allDay, .exact, .range])
        #expect(TaskFormDateAvailabilityMode.allCases == [.none, .exact, .range])
    }

    @Test
    func routineRepeatTypeOptionsIncludeItemRunoutOnlyForChecklistRoutines() {
        let standard = taskFormModel(scheduleMode: .fixedInterval)
        let checklist = taskFormModel(scheduleMode: .fixedIntervalChecklist)
        let runout = taskFormModel(scheduleMode: .derivedFromChecklist)
        let todo = taskFormModel(taskType: .todo, scheduleMode: .oneOff)

        #expect(standard.supportsItemRunoutRepeatType == false)
        #expect(standard.routineRepeatTypeCases == [.interval, .calendar])
        #expect(standard.routineRepeatType.wrappedValue == .interval)
        #expect(checklist.supportsItemRunoutRepeatType)
        #expect(checklist.routineRepeatTypeCases == [.interval, .calendar, .itemRunout])
        #expect(runout.supportsItemRunoutRepeatType)
        #expect(runout.routineRepeatTypeCases == [.interval, .calendar, .itemRunout])
        #expect(runout.routineRepeatType.wrappedValue == .itemRunout)
        #expect(todo.supportsItemRunoutRepeatType == false)
        #expect(todo.routineRepeatTypeCases == [.interval, .calendar])
    }

    @Test @MainActor
    func autoAssumeEligibilityTracksLiveGentleDailyScheduleBindings() {
        var scheduleMode = RoutineScheduleMode.oneOff
        let model = taskFormModel(
            taskType: .todo,
            scheduleModeBinding: Binding(
                get: { scheduleMode },
                set: { scheduleMode = $0 }
            )
        )

        #expect(!model.canAutoAssumeDailyDone)

        scheduleMode = .softInterval
        #expect(model.canAutoAssumeDailyDone)

        scheduleMode = .softIntervalChecklist
        #expect(!model.canAutoAssumeDailyDone)

        let checklistModel = taskFormModel(
            scheduleMode: .softIntervalChecklist,
            checklistItems: [RoutineChecklistItem(title: "Breakfast", intervalDays: 1)]
        )
        let runoutModel = taskFormModel(
            scheduleMode: .derivedFromChecklist,
            checklistItems: [RoutineChecklistItem(title: "Milk", intervalDays: 1)]
        )
        #expect(checklistModel.canAutoAssumeDailyDone)
        #expect(!runoutModel.canAutoAssumeDailyDone)
    }

    @Test @MainActor
    func routineRepeatTypeBindingSwitchesChecklistRunoutScheduleModes() {
        var taskType = RoutineTaskType.routine
        var scheduleMode = RoutineScheduleMode.fixedIntervalChecklist
        var recurrenceKind = RoutineRecurrenceRule.Kind.weekly
        let model = taskFormModel(
            taskTypeBinding: Binding(
                get: { taskType },
                set: { taskType = $0 }
            ),
            scheduleModeBinding: Binding(
                get: { scheduleMode },
                set: { scheduleMode = $0 }
            ),
            recurrenceKindBinding: Binding(
                get: { recurrenceKind },
                set: { recurrenceKind = $0 }
            )
        )

        #expect(model.routineRepeatType.wrappedValue == .calendar)

        model.routineRepeatType.wrappedValue = .itemRunout
        #expect(scheduleMode == .derivedFromChecklist)
        #expect(recurrenceKind == .weekly)
        #expect(model.routineRepeatType.wrappedValue == .itemRunout)

        model.routineRepeatType.wrappedValue = .interval
        #expect(scheduleMode == .fixedIntervalChecklist)
        #expect(recurrenceKind == .intervalDays)
        #expect(model.routineRepeatType.wrappedValue == .interval)

        scheduleMode = .softIntervalChecklist
        model.routineRepeatType.wrappedValue = .itemRunout
        #expect(scheduleMode == .softDerivedFromChecklist)

        model.routineRepeatType.wrappedValue = .calendar
        #expect(scheduleMode == .softIntervalChecklist)
        #expect(recurrenceKind == .weekly)

        taskType = .todo
        model.routineRepeatType.wrappedValue = .itemRunout
        #expect(scheduleMode == .softIntervalChecklist)
    }

    @Test @MainActor
    func calendarRecurrenceKindTreatsDailyAsIntervalFallback() {
        var recurrenceKind = RoutineRecurrenceRule.Kind.dailyTime
        let model = taskFormModel(
            recurrenceKindBinding: Binding(
                get: { recurrenceKind },
                set: { recurrenceKind = $0 }
            )
        )

        #expect(model.routineRepeatType.wrappedValue == .interval)
        #expect(model.repeatBasis.wrappedValue == .interval)
        #expect(model.calendarRecurrenceKind.wrappedValue == .weekly)

        model.calendarRecurrenceKind.wrappedValue = .dailyTime
        #expect(recurrenceKind == .dailyTime)

        model.calendarRecurrenceKind.wrappedValue = .monthlyDay
        #expect(recurrenceKind == .monthlyDay)
    }

    @Test @MainActor
    func multiCalendarSelectionSettersDoNotCollapseToSingleFallbackValue() {
        var recurrenceWeekday = 2
        var recurrenceDayOfMonth = 2
        var recurrenceWeekdays: [Int] = [2]
        var recurrenceDaysOfMonth: [Int] = [2]
        let model = taskFormModel(
            recurrenceWeekdayBinding: Binding(
                get: { recurrenceWeekday },
                set: { recurrenceWeekday = $0 }
            ),
            recurrenceDayOfMonthBinding: Binding(
                get: { recurrenceDayOfMonth },
                set: { recurrenceDayOfMonth = $0 }
            ),
            recurrenceWeekdaysBinding: Binding(
                get: { recurrenceWeekdays },
                set: { recurrenceWeekdays = $0 }
            ),
            recurrenceDaysOfMonthBinding: Binding(
                get: { recurrenceDaysOfMonth },
                set: { recurrenceDaysOfMonth = $0 }
            )
        )

        model.setRecurrenceWeekdays([2, 4, 6])
        model.setRecurrenceDaysOfMonth([2, 12, 24])

        #expect(recurrenceWeekday == 2)
        #expect(recurrenceDayOfMonth == 2)
        #expect(recurrenceWeekdays == [2, 4, 6])
        #expect(recurrenceDaysOfMonth == [2, 12, 24])
    }

    @Test
    func intervalFrequencyBoundsRequireTwoDaysForMultiDayDailyInterval() {
        let oneDay = taskFormModel(
            scheduleMode: .fixedInterval,
            routineDurationMode: .oneDay,
            frequencyUnit: .day,
            frequencyValue: 1
        )
        let multiDayDailyInterval = taskFormModel(
            scheduleMode: .fixedInterval,
            routineDurationMode: .multiDay,
            frequencyUnit: .day,
            frequencyValue: 1
        )
        let multiDayWeeklyInterval = taskFormModel(
            scheduleMode: .fixedInterval,
            routineDurationMode: .multiDay,
            frequencyUnit: .week,
            frequencyValue: 1
        )

        #expect(oneDay.intervalFrequencyValueBounds.lowerBound == 1)
        #expect(multiDayDailyInterval.intervalFrequencyValueBounds.lowerBound == 2)
        #expect(multiDayWeeklyInterval.intervalFrequencyValueBounds.lowerBound == 1)
    }

    @Test
    func durationEntryPresentationBuildsAndClampsHourMinuteValues() {
        #expect(
            TaskFormDurationEntryPresentation.combinedMinutes(
                hours: 20,
                minuteRemainder: 0,
                bounds: TaskFormDurationEntryPresentation.estimatedDurationBounds
            ) == 1_200
        )
        #expect(TaskFormDurationEntryPresentation.hours(for: 1_240) == 20)
        #expect(TaskFormDurationEntryPresentation.minuteRemainder(for: 1_240) == 40)
        #expect(
            TaskFormDurationEntryPresentation.combinedMinutes(
                hours: 0,
                minuteRemainder: 0,
                bounds: TaskFormDurationEntryPresentation.estimatedDurationBounds
            ) == 5
        )
        #expect(
            TaskFormDurationEntryPresentation.combinedMinutes(
                hours: 999,
                minuteRemainder: 90,
                bounds: TaskFormDurationEntryPresentation.actualDurationBounds
            ) == 1_440
        )
        #expect(TaskFormDurationEntryPresentation.durationPresets.contains { $0.minutes == 1_200 && $0.label == "20h" })
    }

    @Test
    func compactSectionOrderKeepsVoiceNoteDiscoverableNearNotes() throws {
        let order = TaskFormCompactSection.defaultOrder
        let notesIndex = try #require(order.firstIndex(of: .notes))
        let voiceNoteIndex = try #require(order.firstIndex(of: .voiceNote))
        let deadlineIndex = try #require(order.firstIndex(of: .deadline))
        let imageIndex = try #require(order.firstIndex(of: .image))
        let goalsIndex = try #require(order.firstIndex(of: .goals))
        let eventsIndex = try #require(order.firstIndex(of: .events))
        let relationshipsIndex = try #require(order.firstIndex(of: .relationships))
        let stepsIndex = try #require(order.firstIndex(of: .steps))
        let checklistIndex = try #require(order.firstIndex(of: .checklist))

        #expect(voiceNoteIndex == order.index(after: notesIndex))
        #expect(voiceNoteIndex < deadlineIndex)
        #expect(voiceNoteIndex < imageIndex)
        #expect(eventsIndex == order.index(after: goalsIndex))
        #expect(relationshipsIndex == order.index(after: eventsIndex))
        #expect(checklistIndex == order.index(after: stepsIndex))
    }

    @Test
    func progressiveVisibilityModesAreOptIn() {
        #expect(!TaskFormVisibilityMode.full.usesProgressiveDisclosure)
        #expect(TaskFormVisibilityMode.progressiveCreate.usesProgressiveDisclosure)
        #expect(TaskFormVisibilityMode.progressiveEdit.usesProgressiveDisclosure)
    }

    @Test
    func compactSectionsDoNotOfferEmptyStandardRoutineChecklistDetails() {
        let routine = taskFormModel(scheduleMode: .fixedInterval)
        let checklistRoutine = taskFormModel(scheduleMode: .fixedIntervalChecklist)
        let runoutRoutine = taskFormModel(scheduleMode: .derivedFromChecklist)
        let existingChecklistRoutine = taskFormModel(
            scheduleMode: .fixedInterval,
            checklistItems: [RoutineChecklistItem(title: "Bread", intervalDays: 3)]
        )
        let todo = taskFormModel(taskType: .todo, scheduleMode: .oneOff)

        #expect(!routine.visibleCompactSections(isShowingMoreDetails: true).contains(.checklist))
        #expect(checklistRoutine.visibleCompactSections(isShowingMoreDetails: false).contains(.checklist))
        #expect(runoutRoutine.visibleCompactSections(isShowingMoreDetails: false).contains(.checklist))
        #expect(runoutRoutine.visibleCompactSections(isShowingMoreDetails: false).contains(.repeatPattern))
        #expect(existingChecklistRoutine.visibleCompactSections(isShowingMoreDetails: false).contains(.checklist))
        #expect(!todo.visibleCompactSections(isShowingMoreDetails: false).contains(.checklist))
        #expect(todo.visibleCompactSections(isShowingMoreDetails: true).contains(.checklist))
        #expect(!routine.visibleCompactSections(isShowingMoreDetails: true).contains(.reminder))
        #expect(todo.visibleCompactSections(isShowingMoreDetails: false).contains(.reminder))
    }

    @Test
    func textFormattingCommandsInsertMarkdownSnippets() {
        #expect(RoutinaTextFormattingCommand.bold.applying(to: "") == "**bold text**")
        #expect(RoutinaTextFormattingCommand.italic.applying(to: "Start") == "Start _italic text_")
        #expect(RoutinaTextFormattingCommand.bulletList.applying(to: "Start") == "Start\n\n- List item")
        #expect(RoutinaTextFormattingCommand.checklist.applying(to: "Start\n") == "Start\n\n- [ ] Checklist item")
        #expect(RoutinaTextFormattingCommand.link.applying(to: "Start ") == "Start [link text](https://example.com)")
    }

    private func presentation(
        taskType: RoutineTaskType = .routine,
        scheduleMode: RoutineScheduleMode = .fixedInterval,
        recurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays,
        recurrenceHasExplicitTime: Bool = false,
        recurrenceHasTimeRange: Bool = false,
        recurrenceWeekday: Int = 2,
        recurrenceDayOfMonth: Int = 1,
        recurrenceWeekdays: [Int] = [],
        recurrenceDaysOfMonth: [Int] = [],
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        hasAvailableTags: Bool = false,
        hasAvailableGoals: Bool = true,
        goalDraft: String = "",
        selectedPlaceName: String? = nil,
        canAutoAssumeDailyDone: Bool = false
    ) -> TaskFormPresentation {
        TaskFormPresentation(
            taskType: taskType,
            scheduleMode: scheduleMode,
            recurrenceKind: recurrenceKind,
            recurrenceHasExplicitTime: recurrenceHasExplicitTime,
            recurrenceHasTimeRange: recurrenceHasTimeRange,
            recurrenceWeekday: recurrenceWeekday,
            recurrenceDayOfMonth: recurrenceDayOfMonth,
            recurrenceWeekdays: recurrenceWeekdays,
            recurrenceDaysOfMonth: recurrenceDaysOfMonth,
            importance: importance,
            urgency: urgency,
            hasAvailableTags: hasAvailableTags,
            hasAvailableGoals: hasAvailableGoals,
            goalDraft: goalDraft,
            selectedPlaceName: selectedPlaceName,
            canAutoAssumeDailyDone: canAutoAssumeDailyDone
        )
    }

    private func taskFormModel(
        taskType: RoutineTaskType = .routine,
        scheduleMode: RoutineScheduleMode = .fixedInterval,
        routineDurationMode: RoutineDurationMode = .oneDay,
        checklistItems: [RoutineChecklistItem] = [],
        recurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays,
        frequencyUnit: TaskFormFrequencyUnit = .day,
        frequencyValue: Int = 1,
        taskTypeBinding: Binding<RoutineTaskType>? = nil,
        scheduleModeBinding: Binding<RoutineScheduleMode>? = nil,
        recurrenceKindBinding: Binding<RoutineRecurrenceRule.Kind>? = nil,
        recurrenceWeekdayBinding: Binding<Int>? = nil,
        recurrenceDayOfMonthBinding: Binding<Int>? = nil,
        recurrenceWeekdaysBinding: Binding<[Int]>? = nil,
        recurrenceDaysOfMonthBinding: Binding<[Int]>? = nil
    ) -> TaskFormModel {
        TaskFormModel(
            name: .constant("Task"),
            nameValidationMessage: nil,
            taskType: taskTypeBinding ?? .constant(taskType),
            emoji: .constant("✨"),
            emojiOptions: [],
            isEmojiPickerPresented: .constant(false),
            notes: .constant(""),
            link: .constant(""),
            deadlineEnabled: .constant(false),
            deadline: .constant(Date()),
            routineDurationMode: .constant(routineDurationMode),
            reminderEnabled: .constant(false),
            reminderAt: .constant(Date()),
            importance: .constant(.level2),
            urgency: .constant(.level2),
            pressure: .constant(.none),
            estimatedDurationMinutes: .constant(nil),
            storyPoints: .constant(nil),
            imageData: nil,
            onImagePicked: { _ in },
            onRemoveImage: {},
            voiceNote: nil,
            onVoiceNoteChanged: { _ in },
            attachments: [],
            onAttachmentPicked: { _, _ in },
            onRemoveAttachment: { _ in },
            tagDraft: .constant(""),
            routineTags: [],
            availableTags: [],
            onAddTag: {},
            onRemoveTag: { _ in },
            onToggleTagSelection: { _ in },
            goalDraft: .constant(""),
            selectedGoals: [],
            availableGoals: [],
            onAddGoal: {},
            onRemoveGoal: { _ in },
            onToggleGoalSelection: { _ in },
            relationships: [],
            availableRelationshipTasks: [],
            onAddRelationship: { _, _ in },
            onRemoveRelationship: { _ in },
            scheduleMode: scheduleModeBinding ?? .constant(scheduleMode),
            stepDraft: .constant(""),
            routineSteps: [],
            onAddStep: {},
            onRemoveStep: { _ in },
            onMoveStepUp: { _ in },
            onMoveStepDown: { _ in },
            checklistItemDraftTitle: .constant(""),
            checklistItemDraftInterval: .constant(3),
            routineChecklistItems: checklistItems,
            onAddChecklistItem: {},
            onRemoveChecklistItem: { _ in },
            availablePlaces: [],
            selectedPlaceID: .constant(nil),
            recurrenceKind: recurrenceKindBinding ?? .constant(recurrenceKind),
            recurrenceHasExplicitTime: .constant(false),
            recurrenceTimeOfDay: .constant(Date()),
            recurrenceWeekday: recurrenceWeekdayBinding ?? .constant(2),
            recurrenceDayOfMonth: recurrenceDayOfMonthBinding ?? .constant(1),
            recurrenceWeekdays: recurrenceWeekdaysBinding ?? .constant([]),
            recurrenceDaysOfMonth: recurrenceDaysOfMonthBinding ?? .constant([]),
            frequencyUnit: .constant(frequencyUnit),
            frequencyValue: .constant(frequencyValue),
            color: .constant(.none),
            visibilityMode: .progressiveCreate
        )
    }
}
