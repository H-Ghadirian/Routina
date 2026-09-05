import Foundation

struct TaskFormPresentation {
    let taskType: RoutineTaskType
    let scheduleMode: RoutineScheduleMode
    let recurrenceKind: RoutineRecurrenceRule.Kind
    let recurrenceHasExplicitTime: Bool
    var recurrenceHasTimeRange: Bool = false
    let recurrenceWeekday: Int
    let recurrenceDayOfMonth: Int
    var recurrenceWeekdays: [Int] = []
    var recurrenceDaysOfMonth: [Int] = []
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let hasAvailableTags: Bool
    let hasAvailableGoals: Bool
    let goalDraft: String
    let selectedPlaceName: String?
    let canAutoAssumeDailyDone: Bool

    var isStepBasedMode: Bool {
        scheduleMode.isStandardRoutineMode || scheduleMode == .oneOff
    }

    var showsRepeatControls: Bool {
        taskType == .routine
            && scheduleMode.usesRoutineCadence
    }

    var derivedPriority: RoutineTaskPriority {
        let score = importance.sortOrder + urgency.sortOrder
        switch score {
        case ..<4: return .low
        case 4...5: return .medium
        case 6...7: return .high
        default: return .urgent
        }
    }

    var notesHelpText: String {
        switch taskType {
        case .todo:
            return "Capture extra context, links, or reminders for this one-time task."
        case .routine:
            return "Add any details you want to keep with this repeating task."
        }
    }

    var linkHelpText: String {
        "Add as many websites as you need. URLs without a scheme will use https."
    }

    var tagSectionHelpText: String {
        "Separate multiple tags with commas."
    }

    var goalSectionHelpText: String {
        if hasAvailableGoals {
            return "Tap an existing goal below, or press return/Add to create a new one. Separate multiple goals with commas."
        }
        return "Press return or Add. Separate multiple goals with commas."
    }

    var canAddGoalDraft: Bool {
        goalDraft
            .split(separator: ",")
            .contains { RoutineGoal.cleanedTitle(String($0)) != nil }
    }

    var scheduleModeDescription: String {
        switch scheduleMode {
        case .fixedInterval: return "One scheduled repeating task. Mark it done once, or advance its steps."
        case .softInterval: return "Always visible. Highlight it again after enough time has passed."
        case .fixedIntervalChecklist: return "One scheduled repeating task that finishes after every checklist item is done."
        case .softIntervalChecklist: return "Always visible. Finish it by completing every checklist item."
        case .derivedFromChecklist: return "Checklist items have their own timing; the earliest due item drives the repeating task."
        case .softDerivedFromChecklist: return "Checklist items have their own timing, without turning the repeating task overdue."
        case .oneOff: return "This task does not repeat."
        }
    }

    var routineFormatDescription: String {
        switch scheduleMode.routineFormat {
        case .standard: return "Mark it done once, or advance its steps."
        case .checklist: return "The repeating task is done when every checklist item is completed."
        case .runout: return "Checklist items have their own timing; the earliest due item drives the repeating task."
        }
    }

    var stepsSectionDescription: String {
        switch scheduleMode {
        case .oneOff:
            return "Steps run in order. Leave this empty for a single-step one-time task."
        default:
            return "Steps run in order. Leave this empty for a one-step repeating task."
        }
    }

    func checklistSectionDescription(includesDerivedChecklistDueDetail: Bool) -> String {
        switch scheduleMode {
        case .fixedIntervalChecklist, .softIntervalChecklist:
            return "The repeating task is done when every checklist item is completed."
        case .derivedFromChecklist, .softDerivedFromChecklist:
            return includesDerivedChecklistDueDetail
                ? "Set how often each item becomes due. The earliest due item makes the repeating task due."
                : "The repeating task becomes due when the earliest checklist item is due."
        case .fixedInterval, .softInterval:
            return "Use checklist items for parts you want to tick off before finishing the repeating task."
        case .oneOff:
            return "Use checklist items for parts you want to tick off before finishing the one-time task."
        }
    }

    var placeSelectionDescription: String {
        if let selectedPlaceName {
            return "Show this task when you are at \(selectedPlaceName)."
        }
        return "Anywhere means the task is always visible."
    }

    var recurrencePatternDescription: String {
        recurrencePatternDescription(includesOptionalExactTimeDetail: true)
    }

    func recurrencePatternDescription(includesOptionalExactTimeDetail: Bool) -> String {
        switch recurrenceKind {
        case .intervalDays: return "Repeat after a fixed number of days, weeks, or months, with optional timing."
        case .dailyTime: return "Repeat every day, with optional timing."
        case .weekly:
            return includesOptionalExactTimeDetail
                ? "Repeat on the same weekday each week, with optional timing."
                : "Repeat on the same weekday each week."
        case .monthlyDay:
            return includesOptionalExactTimeDetail
                ? "Repeat on the same calendar day each month, with optional timing."
                : "Repeat on the same calendar day each month."
        }
    }

    var autoAssumeDailyDoneHelpText: String {
        if canAutoAssumeDailyDone {
            return "Defaults eligible occurrences to done. You can still confirm one or mark it not done later."
        }
        return "Available for eligible schedules without steps or optional checklist items."
    }

    var weekdayOptions: [(id: Int, name: String)] {
        Calendar.current.weekdaySymbols.enumerated().map { (id: $0.offset + 1, name: $0.element) }
    }

    var weeklyRecurrenceSummary: String {
        let selectedWeekdays = selectedWeekdaysForSummary
        guard !selectedWeekdays.isEmpty else { return "Choose at least one weekday." }
        return "Due every \(Self.weekdayListText(for: selectedWeekdays))."
    }

    func dailyRecurrenceTimeHelpText(
        exactTimeText: String,
        timeRangeText: String
    ) -> String {
        if recurrenceHasTimeRange {
            return "Due every day from \(timeRangeText)."
        }
        if recurrenceHasExplicitTime {
            return "Due every day at \(exactTimeText)."
        }
        return "Due every day, any time."
    }

    func intervalRecurrenceTimeHelpText(
        exactTimeText: String,
        timeRangeText: String
    ) -> String {
        if recurrenceHasTimeRange {
            return "Available after the interval, from \(timeRangeText)."
        }
        if recurrenceHasExplicitTime {
            return "Available after the interval, at \(exactTimeText)."
        }
        return "Available any time once the interval has passed."
    }

    func weeklyRecurrenceTimeHelpText(
        explicitTimeText: String? = nil,
        timeRangeText: String? = nil
    ) -> String {
        if recurrenceHasTimeRange {
            guard let timeRangeText else { return weeklyRecurrenceSummary }
            return "Due every \(Self.weekdayListText(for: selectedWeekdaysForSummary)) from \(timeRangeText)."
        }
        if recurrenceHasExplicitTime {
            guard let explicitTimeText else { return weeklyRecurrenceSummary }
            return "Due every \(Self.weekdayListText(for: selectedWeekdaysForSummary)) at \(explicitTimeText)."
        }
        return
            "Optional. Leave this off to keep the repeating task due any time on \(Self.weekdayListText(for: selectedWeekdaysForSummary))."
    }

    var monthlyRecurrenceSummary: String {
        let selectedDays = selectedMonthDaysForSummary
        guard !selectedDays.isEmpty else { return "Choose at least one day of the month." }
        return Self.monthlyDueSentence(for: selectedDays)
    }

    func monthlyRecurrenceTimeHelpText(
        explicitTimeText: String? = nil,
        timeRangeText: String? = nil
    ) -> String {
        if recurrenceHasTimeRange {
            guard let timeRangeText else { return monthlyRecurrenceSummary }
            return Self.monthlyDueSentence(
                for: selectedMonthDaysForSummary,
                timingText: "from \(timeRangeText)"
            )
        }
        if recurrenceHasExplicitTime {
            guard let explicitTimeText else { return monthlyRecurrenceSummary }
            return Self.monthlyDueSentence(
                for: selectedMonthDaysForSummary,
                timingText: "at \(explicitTimeText)"
            )
        }
        return Self.monthlyOptionalAnyTimeSentence(for: selectedMonthDaysForSummary)
    }

    private var selectedWeekdaysForSummary: [Int] {
        Self.clampedWeekdays(recurrenceWeekdays.isEmpty ? [recurrenceWeekday] : recurrenceWeekdays)
    }

    private var selectedMonthDaysForSummary: [Int] {
        Self.clampedMonthDays(recurrenceDaysOfMonth.isEmpty ? [recurrenceDayOfMonth] : recurrenceDaysOfMonth)
    }

    static func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        return symbols[min(max(weekday - 1, 0), symbols.count - 1)]
    }

    static func weekdayListText(for weekdays: [Int]) -> String {
        formattedList(clampedWeekdays(weekdays).map(weekdayName))
    }

    static func ordinalDay(_ day: Int) -> String {
        let resolvedDay = clampedMonthDay(day)
        let suffix: String
        switch resolvedDay % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch resolvedDay % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(resolvedDay)\(suffix)"
    }

    static func monthDayControlLabel(for day: Int) -> String {
        let resolvedDay = clampedMonthDay(day)
        switch resolvedDay {
        case 31:
            return "Last day of each month"
        case 29, 30:
            return "Day \(resolvedDay), or last day in shorter months"
        default:
            return "Day \(resolvedDay) of each month"
        }
    }

    static func monthDayRepeatLabel(for day: Int) -> String {
        let resolvedDay = clampedMonthDay(day)
        switch resolvedDay {
        case 31:
            return "Every last day of the month"
        case 29, 30:
            return "Every \(ordinalDay(resolvedDay)); shorter months use last day"
        default:
            return "Every \(ordinalDay(resolvedDay))"
        }
    }

    static func monthDayRepeatLabel(for days: [Int]) -> String {
        let selectedDays = clampedMonthDays(days)
        guard selectedDays.count > 1 else {
            return monthDayRepeatLabel(for: selectedDays.first ?? 1)
        }
        return "Every \(formattedList(selectedDays.map(monthDayListLabel)))"
    }

    static func monthlyScheduleSummary(
        for day: Int,
        timingText: String? = nil
    ) -> String {
        let resolvedDay = clampedMonthDay(day)
        let suffix = timingText.map { " \($0)" } ?? ""
        switch resolvedDay {
        case 31:
            return "Monthly on the last day of the month\(suffix)"
        case 29, 30:
            return "Monthly on the \(ordinalDay(resolvedDay))\(suffix); shorter months use last day"
        default:
            return "Monthly on the \(ordinalDay(resolvedDay))\(suffix)"
        }
    }

    static func monthlyScheduleSummary(
        for days: [Int],
        timingText: String? = nil
    ) -> String {
        let selectedDays = clampedMonthDays(days)
        guard selectedDays.count > 1 else {
            return monthlyScheduleSummary(for: selectedDays.first ?? 1, timingText: timingText)
        }
        let suffix = timingText.map { " \($0)" } ?? ""
        let fallback = selectedDays.contains { $0 >= 29 } ? "; shorter months use last day" : ""
        return "Monthly on the \(formattedList(selectedDays.map(monthDayListLabel)))\(suffix)\(fallback)"
    }

    static func stepperLabel(unit: TaskFormFrequencyUnit, value: Int) -> String {
        if value == 1 {
            return "Every \(unit.singularLabel)"
        }
        return "Every \(value) \(unit.singularLabel)s"
    }

    static func checklistIntervalLabel(for days: Int) -> String {
        days == 1 ? "Every day" : "Every \(days) days"
    }

    private static func monthlyDueSentence(
        for day: Int,
        timingText: String? = nil
    ) -> String {
        let resolvedDay = clampedMonthDay(day)
        let suffix = timingText.map { " \($0)" } ?? ""
        switch resolvedDay {
        case 31:
            return "Due on the last day of each month\(suffix)."
        case 29, 30:
            return "Due on the \(ordinalDay(resolvedDay))\(suffix); shorter months use their last day."
        default:
            return "Due on the \(ordinalDay(resolvedDay)) of each month\(suffix)."
        }
    }

    private static func monthlyDueSentence(
        for days: [Int],
        timingText: String? = nil
    ) -> String {
        let selectedDays = clampedMonthDays(days)
        guard selectedDays.count > 1 else {
            return monthlyDueSentence(for: selectedDays.first ?? 1, timingText: timingText)
        }
        let suffix = timingText.map { " \($0)" } ?? ""
        let fallback = selectedDays.contains { $0 >= 29 } ? "; shorter months use their last day" : ""
        return "Due on the \(formattedList(selectedDays.map(monthDayListLabel))) of each month\(suffix)\(fallback)."
    }

    private static func monthlyOptionalAnyTimeSentence(for day: Int) -> String {
        let resolvedDay = clampedMonthDay(day)
        switch resolvedDay {
        case 31:
            return "Optional. Leave this off to keep the repeating task due any time on the last day of each month."
        case 29, 30:
            return
                "Optional. Leave this off to keep the repeating task due any time on the \(ordinalDay(resolvedDay)); shorter months use their last day."
        default:
            return "Optional. Leave this off to keep the repeating task due any time on the \(ordinalDay(resolvedDay)) of each month."
        }
    }

    private static func monthlyOptionalAnyTimeSentence(for days: [Int]) -> String {
        let selectedDays = clampedMonthDays(days)
        guard selectedDays.count > 1 else {
            return monthlyOptionalAnyTimeSentence(for: selectedDays.first ?? 1)
        }
        return
            "Optional. Leave this off to keep the repeating task due any time on the \(formattedList(selectedDays.map(monthDayListLabel)))."
    }

    private static func clampedMonthDay(_ day: Int) -> Int {
        min(max(day, 1), 31)
    }

    private static func clampedWeekdays(_ weekdays: [Int]) -> [Int] {
        Array(Set(weekdays.map { min(max($0, 1), 7) })).sorted()
    }

    private static func clampedMonthDays(_ days: [Int]) -> [Int] {
        Array(Set(days.map(clampedMonthDay))).sorted()
    }

    private static func monthDayListLabel(for day: Int) -> String {
        let resolvedDay = clampedMonthDay(day)
        return resolvedDay == 31 ? "last day" : ordinalDay(resolvedDay)
    }

    private static func formattedList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            return "\(values.dropLast().joined(separator: ", ")), and \(values.last ?? "")"
        }
    }

    static func estimatedDurationLabel(for minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let remainingMinutes):
            return remainingMinutes == 1 ? "1 minute" : "\(remainingMinutes) minutes"
        case (let hours, 0):
            return hours == 1 ? "1 hour" : "\(hours) hours"
        default:
            let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
            let minuteText = remainingMinutes == 1 ? "1 minute" : "\(remainingMinutes) minutes"
            return "\(hourText) \(minuteText)"
        }
    }

    static func storyPointsLabel(for points: Int) -> String {
        points == 1 ? "1 story point" : "\(points) story points"
    }
}
