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
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test
    func sidebarPathPresentationShowsResolvedAutomaticPathInsteadOfDefault() {
        #expect(
            TaskFormSidebarPathPresentation.title(
                explicitPathTitles: nil,
                automaticPathTitles: ["Work", "Deep Focus"]
            ) == "Work › Deep Focus (Automatic)"
        )
        #expect(
            TaskFormSidebarPathPresentation.title(
                explicitPathTitles: ["Personal"],
                automaticPathTitles: ["Today"]
            ) == "Personal"
        )
        #expect(
            TaskFormSidebarPathPresentation.title(
                explicitPathTitles: nil,
                automaticPathTitles: nil
            ) == "Automatic"
        )
    }

    @Test
    func editAutomaticPathUsesLiveSidebarLocationOnlyForUnassignedTasks() {
        let manualSectionID = UUID()

        #expect(
            TaskFormSidebarPathPresentation.automaticPathTitles(
                customTaskSectionID: nil,
                sidebarPathTitles: ["Future", "Work"]
            ) == ["Future", "Work"]
        )
        #expect(
            TaskFormSidebarPathPresentation.automaticPathTitles(
                customTaskSectionID: manualSectionID,
                sidebarPathTitles: ["Work"]
            ) == nil
        )
    }

    @Test
    func userFacingTaskTypeSelectorsContainOnlyRoutineAndTodo() {
        #expect(RoutineTaskType.routine.userFacingTitle == "Routine")
        #expect(RoutineTaskType.allCases.map(\.userFacingTitle) == ["Routine", "Todo"])
        #expect(RoutineTaskType.routine.pluralTitle == "Routines")
        #expect(HomeTaskListMode.allCases == [.all, .routines, .todos])
        #expect(!TimelineFilterType.allCases.map(\.rawValue).contains("Records"))
        #expect(StatsTaskTypeFilter.allCases == [.all, .routines, .todos])
    }

    @Test @MainActor
    func creationKindCreatesRepeatingRoutinesWithoutAnExtraPurposeSelector() {
        var taskType = RoutineTaskType.todo
        var cadenceEnabled = false
        let model = taskFormModel(
            taskTypeBinding: Binding(
                get: { taskType },
                set: { taskType = $0 }
            ),
            cadenceEnabledBinding: Binding(
                get: { cadenceEnabled },
                set: { cadenceEnabled = $0 }
            )
        )

        #expect(model.creationKind.wrappedValue == .oneTime)

        model.creationKind.wrappedValue = .repeating
        #expect(taskType == .routine)
        #expect(!cadenceEnabled)
        #expect(!model.supportsAdvancedRecurrence)
        #expect(!model.supportsRoutineScheduleBehavior)
        #expect(!model.supportsGentleNudges)
        #expect(!model.supportsRecurrenceAvailability)
        #expect(model.supportsPlanning)
    }

    @Test @MainActor
    func progressiveEditMapsRoutineToRepeatingWithoutExtraPurposeState() {
        var taskType = RoutineTaskType.routine
        var cadenceEnabled = false
        let model = taskFormModel(
            taskTypeBinding: Binding(
                get: { taskType },
                set: { taskType = $0 }
            ),
            cadenceEnabledBinding: Binding(
                get: { cadenceEnabled },
                set: { cadenceEnabled = $0 }
            ),
            visibilityMode: .progressiveEdit
        )

        #expect(model.creationKind.wrappedValue == .repeating)
        #expect(model.visibilityMode.usesProgressiveDisclosure)
        #expect(model.routineRepeatTypeCases.contains(.none))
        #expect(model.routineRepeatType.wrappedValue == .none)

        model.creationKind.wrappedValue = .oneTime
        #expect(taskType == .todo)
    }

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
        #expect(
            runout.checklistSectionDescription(includesDerivedChecklistDueDetail: true)
                == "Set how often each item becomes due. The earliest due item makes the routine due."
        )
        #expect(gentle.showsRepeatControls)

        #expect(oneOff.isStepBasedMode)
        #expect(oneOff.showsRepeatControls == false)
        #expect(oneOff.notesHelpText == "Capture extra context, links, or reminders for this todo.")
        #expect(oneOff.checklistSectionDescription(includesDerivedChecklistDueDetail: false) == "Use checklist items for parts you want to tick off before finishing the todo.")
        #expect(RoutineScheduleMode.softInterval.scheduleBehavior == .soft)
        #expect(RoutineScheduleMode.softInterval.replacingRoutineFinishMode(.checklist) == .softIntervalChecklist)
        #expect(RoutineScheduleMode.softIntervalChecklist.replacingRoutineFinishMode(.standard) == .softInterval)
    }

    @Test
    func goalPlaceAndGeneralHelpTextAreSharedAcrossPlatforms() {
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
        #expect(TaskFormPresentation.checklistIntervalLabel(for: 1) == "Every day")
        #expect(TaskFormPresentation.checklistIntervalLabel(for: 2) == "Every 2 days")
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
    func effortPresentationNamesIndependentValuesAndActions() {
        #expect(TaskFormEffortPresentation.sectionTitle == "Effort")
        #expect(TaskFormEffortPresentation.timeEstimateDetail == "Planned duration")
        #expect(TaskFormEffortPresentation.actualTimeDetail == "Recorded duration")
        #expect(TaskFormEffortPresentation.storyPointsDetail == "Relative size")
        #expect(TaskFormEffortPresentation.focusTimerDetail == "Attention-session tracking")

        #expect(TaskFormEffortPresentation.timeEstimateActionTitle(minutes: nil) == "Set")
        #expect(TaskFormEffortPresentation.timeEstimateActionTitle(minutes: 30) == "Remove")
        #expect(TaskFormEffortPresentation.actualTimeActionTitle(minutes: nil) == "Log")
        #expect(TaskFormEffortPresentation.actualTimeActionTitle(minutes: 30) == "Clear")
        #expect(TaskFormEffortPresentation.storyPointsActionTitle(points: nil) == "Set")
        #expect(TaskFormEffortPresentation.storyPointsActionTitle(points: 3) == "Remove")
    }

    @Test @MainActor
    func effortValueActionsMutateOnlyTheirOwnField() {
        var estimate: Int? = nil
        var actual: Int? = nil
        var storyPoints: Int? = nil
        let model = taskFormModel(
            taskType: .todo,
            estimatedDurationBinding: Binding(
                get: { estimate },
                set: { estimate = $0 }
            ),
            actualDurationBinding: Binding(
                get: { actual },
                set: { actual = $0 }
            ),
            storyPointsBinding: Binding(
                get: { storyPoints },
                set: { storyPoints = $0 }
            )
        )

        model.addEstimatedDuration()
        #expect(estimate == 30)
        #expect(actual == nil)
        #expect(storyPoints == nil)

        model.estimatedDurationValue.wrappedValue = 90
        model.addActualDuration()
        #expect(estimate == 90)
        #expect(actual == 30)
        #expect(storyPoints == nil)

        model.addStoryPoints()
        #expect(estimate == 90)
        #expect(actual == 30)
        #expect(storyPoints == 1)

        model.clearActualDuration()
        #expect(estimate == 90)
        #expect(actual == nil)
        #expect(storyPoints == 1)
    }

    @Test
    func moreScheduleOptionsUseOneResponsiveFixedSchedulePresentation() {
        #expect(
            TaskFormFixedSchedulePresentation.startIncludesTime(
                frequency: .hourly,
                availabilityUsesWindow: false
            )
        )
        #expect(
            !TaskFormFixedSchedulePresentation.startIncludesTime(
                frequency: .weekly,
                availabilityUsesWindow: false
            )
        )
        #expect(
            TaskFormFixedSchedulePresentation.inlinesSingleOccurrenceTime(
                isDesktop: true,
                frequency: .weekly,
                occurrenceTimeCount: 1
            )
        )
        #expect(
            !TaskFormFixedSchedulePresentation.inlinesSingleOccurrenceTime(
                isDesktop: false,
                frequency: .weekly,
                occurrenceTimeCount: 1
            )
        )
        #expect(
            !TaskFormFixedSchedulePresentation.inlinesSingleOccurrenceTime(
                isDesktop: true,
                frequency: .daily,
                occurrenceTimeCount: 1
            )
        )

        let compactDraft = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .weekly,
            weekdays: [2]
        )
        #expect(
            TaskFormFixedSchedulePresentation.summary(for: compactDraft)
                == "Default"
        )

        let fixedDraft = RoutineRecurrenceDraft(
            cadence: .scheduled,
            frequency: .weekly,
            startDate: Date(timeIntervalSince1970: 0),
            weekdays: [2],
            occurrenceTimes: [RoutineTimeOfDay(hour: 9, minute: 0)],
            endMode: .never,
            timeZoneIdentifier: "UTC"
        )
        let summary = TaskFormFixedSchedulePresentation.summary(
            for: fixedDraft
        )
        #expect(summary.hasPrefix("Starts "))
        #expect(summary.hasSuffix(" · Never ends"))
    }

    @Test
    func availabilityModesMatchPersistedTaskTypeSupport() {
        #expect(TaskFormTimingMode.cases(for: .todo) == [.none, .allDay, .exact, .timeBlock, .availableWindow])
        #expect(TaskFormTimingMode.cases(for: .routine) == [.none, .allDay, .exact, .timeBlock, .availableWindow])
        #expect(TaskFormTimingMode.cases(for: .routine) == [.none, .allDay, .exact, .timeBlock, .availableWindow])
        #expect(TaskFormTimingMode.timeBlock.usesTimeRange)
        #expect(TaskFormTimingMode.availableWindow.usesTimeRange)
        #expect(TaskFormTimingMode.timeBlock.timeRangeRole == .scheduledBlock)
        #expect(TaskFormTimingMode.availableWindow.timeRangeRole == .availability)
        #expect(
            TaskFormTimingMode.timeBlock.timeRangeHelpText(startTimeText: "07:00", endTimeText: "10:00")
                == "Reserve the full time from 07:00 to 10:00"
        )
        #expect(
            TaskFormTimingMode.availableWindow.timeRangeHelpText(startTimeText: "07:00", endTimeText: "10:00")
                == "Can be scheduled anytime between 07:00 and 10:00"
        )
        #expect(
            TaskFormTimingMode.exact.timeRangeHelpText(startTimeText: "07:00", endTimeText: "10:00") == nil
        )
        let inheritedRange = TaskFormTimingMode.timeRangeInheritingExactTime(
            RoutineTimeOfDay(hour: 15, minute: 0)
        )
        #expect(inheritedRange.start == RoutineTimeOfDay(hour: 15, minute: 0))
        #expect(inheritedRange.end == RoutineTimeOfDay(hour: 18, minute: 0))
        #expect(TaskFormDateAvailabilityMode.allCases == [.none, .exact, .range])
    }

    @Test
    func oneOffReminderEventUsesTheStartOfTimeRange() throws {
        let availabilityDate = makeDate("2026-08-25T00:00:00Z")
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 15, minute: 0),
            end: RoutineTimeOfDay(hour: 18, minute: 0)
        )
        let eventDate = try #require(
            TaskFormReminderLeadTime.eventDate(
                scheduleMode: .oneOff,
                deadline: nil,
                recurrenceRule: .interval(days: 1, timeRange: timeRange),
                availabilityStartDate: availabilityDate,
                availabilityEndDate: nil,
                referenceDate: availabilityDate,
                calendar: calendar
            )
        )

        #expect(eventDate == makeDate("2026-08-25T15:00:00Z"))
    }

    @Test
    func routineRepeatTypeOptionsIncludeItemRunoutOnlyForChecklistRoutines() {
        let standard = taskFormModel(scheduleMode: .fixedInterval)
        let checklist = taskFormModel(scheduleMode: .fixedIntervalChecklist)
        let runout = taskFormModel(scheduleMode: .derivedFromChecklist)
        let recordWithoutCadence = taskFormModel(
            taskType: .routine,
            scheduleMode: .softInterval,
            cadenceEnabled: false
        )
        let checklistRecord = taskFormModel(
            taskType: .routine,
            scheduleMode: .softIntervalChecklist,
            cadenceEnabled: true
        )
        let runoutRecord = taskFormModel(
            taskType: .routine,
            scheduleMode: .softDerivedFromChecklist,
            cadenceEnabled: true
        )
        let todo = taskFormModel(taskType: .todo, scheduleMode: .oneOff)

        #expect(standard.supportsItemRunoutRepeatType == false)
        #expect(standard.routineRepeatTypeCases == [.none, .interval, .calendar])
        #expect(standard.routineRepeatType.wrappedValue == .interval)
        #expect(checklist.supportsItemRunoutRepeatType)
        #expect(checklist.routineRepeatTypeCases == [.none, .interval, .calendar, .itemRunout])
        #expect(runout.supportsItemRunoutRepeatType)
        #expect(runout.routineRepeatTypeCases == [.none, .interval, .calendar, .itemRunout])
        #expect(runout.routineRepeatType.wrappedValue == .itemRunout)
        #expect(recordWithoutCadence.routineRepeatTypeCases == [.none, .interval, .calendar])
        #expect(recordWithoutCadence.routineRepeatType.wrappedValue == .none)
        #expect(checklistRecord.supportsItemRunoutRepeatType)
        #expect(checklistRecord.routineRepeatTypeCases == [.none, .interval, .calendar, .itemRunout])
        #expect(runoutRecord.supportsItemRunoutRepeatType)
        #expect(runoutRecord.routineRepeatType.wrappedValue == .itemRunout)
        #expect(todo.supportsItemRunoutRepeatType == false)
        #expect(todo.routineRepeatTypeCases == [.interval, .calendar])
    }

    @Test @MainActor
    func gentleNudgesAndAutoAssumeFollowCadenceAndScheduleEligibility() {
        var scheduleMode = RoutineScheduleMode.oneOff
        let model = taskFormModel(
            taskType: .routine,
            scheduleModeBinding: Binding(
                get: { scheduleMode },
                set: { scheduleMode = $0 }
            )
        )

        #expect(!model.canAutoAssumeDailyDone)

        scheduleMode = .softInterval
        #expect(model.canAutoAssumeDailyDone)
        #expect(model.supportsGentleNudges)

        scheduleMode = .softIntervalChecklist
        #expect(!model.canAutoAssumeDailyDone)

        let checklistModel = taskFormModel(
            taskType: .routine,
            scheduleMode: .softIntervalChecklist,
            checklistItems: [RoutineChecklistItem(title: "Breakfast", intervalDays: 1)]
        )
        let runoutModel = taskFormModel(
            taskType: .routine,
            scheduleMode: .softDerivedFromChecklist,
            checklistItems: [RoutineChecklistItem(title: "Milk", intervalDays: 1)]
        )
        let noCadenceModel = taskFormModel(
            taskType: .routine,
            scheduleMode: .softInterval,
            cadenceEnabled: false
        )
        let gentleRoutineModel = taskFormModel(scheduleMode: .softInterval)
        let dueRoutineModel = taskFormModel(scheduleMode: .fixedInterval)
        let noCadenceGentleRoutineModel = taskFormModel(
            scheduleMode: .softInterval,
            cadenceEnabled: false
        )
        let gentleChecklistModel = taskFormModel(
            scheduleMode: .softIntervalChecklist,
            checklistItems: [RoutineChecklistItem(title: "Breakfast", intervalDays: 1)]
        )

        #expect(checklistModel.canAutoAssumeDailyDone)
        #expect(!runoutModel.canAutoAssumeDailyDone)
        #expect(!noCadenceModel.canAutoAssumeDailyDone)
        #expect(gentleRoutineModel.canAutoAssumeDailyDone)
        #expect(gentleRoutineModel.supportsGentleNudges)
        #expect(dueRoutineModel.canAutoAssumeDailyDone)
        #expect(!dueRoutineModel.supportsGentleNudges)
        #expect(!noCadenceGentleRoutineModel.canAutoAssumeDailyDone)
        #expect(!noCadenceGentleRoutineModel.supportsGentleNudges)
        #expect(gentleChecklistModel.canAutoAssumeDailyDone)
    }

    @Test @MainActor
    func routineRepeatTypeBindingSwitchesChecklistRunoutScheduleModes() {
        var taskType = RoutineTaskType.routine
        var scheduleMode = RoutineScheduleMode.fixedIntervalChecklist
        var recurrenceKind = RoutineRecurrenceRule.Kind.weekly
        var cadenceEnabled = true
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
            ),
            cadenceEnabledBinding: Binding(
                get: { cadenceEnabled },
                set: { cadenceEnabled = $0 }
            )
        )

        #expect(model.routineRepeatType.wrappedValue == .calendar)

        model.routineRepeatType.wrappedValue = .none
        #expect(!cadenceEnabled)
        #expect(scheduleMode == .fixedIntervalChecklist)
        #expect(model.routineRepeatType.wrappedValue == .none)

        model.routineRepeatType.wrappedValue = .calendar
        #expect(cadenceEnabled)

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

        taskType = .routine
        scheduleMode = .softIntervalChecklist
        model.routineRepeatType.wrappedValue = .itemRunout
        #expect(scheduleMode == .softDerivedFromChecklist)

        model.routineRepeatType.wrappedValue = .none
        #expect(!cadenceEnabled)
        #expect(scheduleMode == .softIntervalChecklist)
        #expect(model.routineRepeatType.wrappedValue == .none)

        model.routineRepeatType.wrappedValue = .interval
        #expect(cadenceEnabled)
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
        let taskTypeIndex = try #require(order.firstIndex(of: .taskType))
        let scheduleTypeIndex = try #require(order.firstIndex(of: .scheduleType))
        let repeatIndex = try #require(order.firstIndex(of: .repeatPattern))
        let taskLadderIndex = try #require(order.firstIndex(of: .taskLadderValues))
        let organizationIndex = try #require(order.firstIndex(of: .organization))
        let descriptionIndex = try #require(order.firstIndex(of: .taskDescription))
        let notesIndex = try #require(order.firstIndex(of: .notes))
        let voiceNoteIndex = try #require(order.firstIndex(of: .voiceNote))
        let deadlineIndex = try #require(order.firstIndex(of: .deadline))
        let imageIndex = try #require(order.firstIndex(of: .image))
        let goalsIndex = try #require(order.firstIndex(of: .goals))
        let eventsIndex = try #require(order.firstIndex(of: .events))
        let relationshipsIndex = try #require(order.firstIndex(of: .relationships))
        let stepsIndex = try #require(order.firstIndex(of: .steps))
        let checklistIndex = try #require(order.firstIndex(of: .checklist))

        #expect(deadlineIndex == order.index(after: taskTypeIndex))
        #expect(repeatIndex == order.index(after: scheduleTypeIndex))
        #expect(taskLadderIndex == order.index(after: repeatIndex))
        #expect(organizationIndex == order.index(after: taskLadderIndex))
        #expect(descriptionIndex == order.index(after: organizationIndex))
        #expect(voiceNoteIndex == order.index(after: notesIndex))
        #expect(voiceNoteIndex < imageIndex)
        #expect(eventsIndex == order.index(after: goalsIndex))
        #expect(relationshipsIndex == order.index(after: eventsIndex))
        #expect(checklistIndex == order.index(after: stepsIndex))
    }

    @Test
    func taskLadderValuesStayVisibleAndExplainTimeBasedEligibility() {
        let repeatingDue = taskFormModel(scheduleMode: .fixedInterval)
        let gentleRoutine = taskFormModel(scheduleMode: .softInterval)
        let cadenceFreeRoutine = taskFormModel(
            scheduleMode: .fixedInterval,
            cadenceEnabled: false
        )
        let oneOffTask = taskFormModel(taskType: .todo, scheduleMode: .oneOff)
        let alreadyConfigured = taskFormModel(
            scheduleMode: .softInterval,
            temporalWeightRule: RoutineTaskTemporalWeightRule(pressureAtDue: .high)
        )

        for model in [repeatingDue, gentleRoutine, cadenceFreeRoutine, oneOffTask, alreadyConfigured] {
            #expect(model.visibleCompactSections(isShowingMoreDetails: false).contains(.taskLadderValues))
        }
        #expect(repeatingDue.supportsTemporalWeightValues)
        #expect(repeatingDue.temporalWeightAvailabilityMessage == nil)
        #expect(gentleRoutine.temporalWeightAvailabilityMessage == "Choose Due in Behavior & Schedule.")
        #expect(cadenceFreeRoutine.temporalWeightAvailabilityMessage == "Choose After done or On schedule in Behavior & Schedule.")
        #expect(oneOffTask.temporalWeightAvailabilityMessage == "Available for repeating tasks.")
    }

    @Test
    func progressiveVisibilityModesAreOptIn() {
        #expect(!TaskFormVisibilityMode.full.usesProgressiveDisclosure)
        #expect(TaskFormVisibilityMode.progressiveCreate.usesProgressiveDisclosure)
        #expect(TaskFormVisibilityMode.progressiveEdit.usesProgressiveDisclosure)
    }

    @Test
    func compactSectionsKeepChecklistAccessibleAndAutoRevealConfiguredCompletion() {
        let routine = taskFormModel(scheduleMode: .fixedInterval)
        let checklistRoutine = taskFormModel(scheduleMode: .fixedIntervalChecklist)
        let runoutRoutine = taskFormModel(scheduleMode: .derivedFromChecklist)
        let gentleChecklistRoutine = taskFormModel(taskType: .routine, scheduleMode: .softIntervalChecklist)
        let existingChecklistRoutine = taskFormModel(
            scheduleMode: .fixedInterval,
            checklistItems: [RoutineChecklistItem(title: "Bread", intervalDays: 3)]
        )
        let todo = taskFormModel(taskType: .todo, scheduleMode: .oneOff)

        #expect(routine.visibleCompactSections(isShowingMoreDetails: true).contains(.checklist))
        #expect(checklistRoutine.visibleCompactSections(isShowingMoreDetails: false).contains(.checklist))
        #expect(runoutRoutine.visibleCompactSections(isShowingMoreDetails: false).contains(.checklist))
        #expect(runoutRoutine.visibleCompactSections(isShowingMoreDetails: false).contains(.repeatPattern))
        #expect(gentleChecklistRoutine.visibleCompactSections(isShowingMoreDetails: false).contains(.checklist))
        #expect(gentleChecklistRoutine.visibleCompactSections(isShowingMoreDetails: false).contains(.repeatPattern))
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
        cadenceEnabled: Bool = true,
        taskTypeBinding: Binding<RoutineTaskType>? = nil,
        scheduleModeBinding: Binding<RoutineScheduleMode>? = nil,
        recurrenceKindBinding: Binding<RoutineRecurrenceRule.Kind>? = nil,
        recurrenceWeekdayBinding: Binding<Int>? = nil,
        recurrenceDayOfMonthBinding: Binding<Int>? = nil,
        recurrenceWeekdaysBinding: Binding<[Int]>? = nil,
        recurrenceDaysOfMonthBinding: Binding<[Int]>? = nil,
        cadenceEnabledBinding: Binding<Bool>? = nil,
        estimatedDurationBinding: Binding<Int?>? = nil,
        actualDurationBinding: Binding<Int?>? = nil,
        storyPointsBinding: Binding<Int?>? = nil,
        temporalWeightRule: RoutineTaskTemporalWeightRule? = nil,
        visibilityMode: TaskFormVisibilityMode = .progressiveCreate
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
            temporalWeightRule: .constant(temporalWeightRule),
            estimatedDurationMinutes: estimatedDurationBinding ?? .constant(nil),
            actualDurationMinutes: actualDurationBinding,
            storyPoints: storyPointsBinding ?? .constant(nil),
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
            cadenceEnabled: cadenceEnabledBinding ?? .constant(cadenceEnabled),
            color: .constant(.none),
            visibilityMode: visibilityMode
        )
    }

    private func makeDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? Date(timeIntervalSince1970: 0)
    }
}
