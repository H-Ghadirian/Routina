import Foundation
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
        let oneOff = presentation(taskType: .todo, scheduleMode: .oneOff)

        #expect(fixed.isStepBasedMode == false)
        #expect(fixed.showsRepeatControls)
        #expect(fixed.scheduleModeDescription == "Use one overall repeat interval and complete every checklist item to finish the routine.")
        #expect(fixed.checklistSectionDescription(includesDerivedChecklistDueDetail: false) == "The routine is done when every checklist item is completed.")

        #expect(oneOff.isStepBasedMode)
        #expect(oneOff.showsRepeatControls == false)
        #expect(oneOff.taskTypeDescription == "Todos are one-off tasks. Once you finish one, it stays completed.")
        #expect(oneOff.notesHelpText == "Capture extra context, links, or reminders for this todo.")
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
        #expect(value.tagSectionHelpText == "Tap an existing tag below, open Manage Tags, or press return/Add to create a new one. Separate multiple tags with commas.")
        #expect(value.goalSectionHelpText == "Press return or Add. Separate multiple goals with commas.")
        #expect(value.linkHelpText == "Add a website to open from the task detail screen. If you skip the scheme, https will be used.")
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
        let weekdaySymbols = Calendar.current.weekdaySymbols

        #expect(TaskFormPresentation.weekdayName(for: 99) == weekdaySymbols.last)
        #expect(TaskFormPresentation.ordinalDay(33) == "31st")
        #expect(weekly.recurrencePatternDescription(includesOptionalExactTimeDetail: false) == "Repeat after a fixed number of days, weeks, or months.")
        #expect(presentation(recurrenceKind: .weekly).recurrencePatternDescription(includesOptionalExactTimeDetail: false) == "Repeat on the same weekday each week.")
        #expect(presentation(recurrenceKind: .monthlyDay).recurrencePatternDescription(includesOptionalExactTimeDetail: false) == "Repeat on the same calendar day each month.")
        #expect(TaskFormPresentation.stepperLabel(unit: .week, value: 1) == "Every week")
        #expect(TaskFormPresentation.stepperLabel(unit: .month, value: 3) == "Every 3 months")
        #expect(TaskFormPresentation.checklistIntervalLabel(for: 2) == "Runs out in 2 days")
        #expect(TaskFormPresentation.estimatedDurationLabel(for: 125) == "2 hours 5 minutes")
        #expect(TaskFormPresentation.storyPointsLabel(for: 1) == "1 story point")
        #expect(weekly.weeklyRecurrenceTimeHelpText() == "Optional. Leave this off to keep the routine due any time on \(weekdaySymbols[1]).")
        #expect(monthly.monthlyRecurrenceTimeHelpText(explicitTimeText: "9:30 AM") == "Due on the 11th of each month at 9:30 AM.")
    }

    private func presentation(
        taskType: RoutineTaskType = .routine,
        scheduleMode: RoutineScheduleMode = .fixedInterval,
        recurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays,
        recurrenceHasExplicitTime: Bool = false,
        recurrenceWeekday: Int = 2,
        recurrenceDayOfMonth: Int = 1,
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
            recurrenceWeekday: recurrenceWeekday,
            recurrenceDayOfMonth: recurrenceDayOfMonth,
            importance: importance,
            urgency: urgency,
            hasAvailableTags: hasAvailableTags,
            hasAvailableGoals: hasAvailableGoals,
            goalDraft: goalDraft,
            selectedPlaceName: selectedPlaceName,
            canAutoAssumeDailyDone: canAutoAssumeDailyDone
        )
    }
}
