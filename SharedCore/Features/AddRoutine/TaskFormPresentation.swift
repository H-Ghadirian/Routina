import Foundation

enum TaskFormFrequencyUnit: String, CaseIterable, Equatable, Sendable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var daysMultiplier: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        }
    }

    var singularLabel: String { rawValue.lowercased() }
}

struct TaskFormPresentation {
    let taskType: RoutineTaskType
    let scheduleMode: RoutineScheduleMode
    let recurrenceKind: RoutineRecurrenceRule.Kind
    let recurrenceHasExplicitTime: Bool
    let recurrenceWeekday: Int
    let recurrenceDayOfMonth: Int
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let hasAvailableTags: Bool
    let hasAvailableGoals: Bool
    let goalDraft: String
    let selectedPlaceName: String?
    let canAutoAssumeDailyDone: Bool

    var isStepBasedMode: Bool {
        scheduleMode == .fixedInterval || scheduleMode == .softInterval || scheduleMode == .oneOff
    }

    var showsRepeatControls: Bool {
        scheduleMode != .derivedFromChecklist && scheduleMode != .oneOff
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

    var taskTypeDescription: String {
        switch taskType {
        case .routine: return "Routines repeat on a schedule and stay in your rotation."
        case .todo: return "Todos are one-off tasks. Once you finish one, it stays completed."
        }
    }

    var notesHelpText: String {
        taskType == .todo
            ? "Capture extra context, links, or reminders for this todo."
            : "Add any details you want to keep with this routine."
    }

    func importanceUrgencyDescription(
        includesDerivedPriority: Bool,
        priority: RoutineTaskPriority? = nil
    ) -> String {
        let base = "\(importance.title) importance and \(urgency.title.lowercased()) urgency"
        guard includesDerivedPriority else { return "\(base)." }
        let resolvedPriority = priority ?? derivedPriority
        return "\(base) map to \(resolvedPriority.title.lowercased()) priority for sorting."
    }

    var estimationHelpText: String {
        taskType == .todo
            ? "Estimate is the plan. Actual time records what really happened."
            : "Estimate is the plan. Routines record actual time on each completion."
    }

    var linkHelpText: String {
        "Add a website to open from the task detail screen. If you skip the scheme, https will be used."
    }

    var tagSectionHelpText: String {
        if hasAvailableTags {
            return "Tap an existing tag below, open Manage Tags, or press return/Add to create a new one. Separate multiple tags with commas."
        }
        return "Press return or Add. Separate multiple tags with commas, or open Manage Tags."
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
        case .fixedInterval: return "Use one overall repeat interval for the whole routine."
        case .softInterval: return "Keep this routine visible all the time and gently highlight it again after a while."
        case .fixedIntervalChecklist: return "Use one overall repeat interval and complete every checklist item to finish the routine."
        case .derivedFromChecklist: return "Use checklist item due dates to decide when the routine is due."
        case .oneOff: return "This task does not repeat."
        }
    }

    var stepsSectionDescription: String {
        scheduleMode == .oneOff
            ? "Steps run in order. Leave this empty for a single-step todo."
            : "Steps run in order. Leave this empty for a one-step routine."
    }

    func checklistSectionDescription(includesDerivedChecklistDueDetail: Bool) -> String {
        switch scheduleMode {
        case .fixedIntervalChecklist:
            return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist:
            return includesDerivedChecklistDueDetail
                ? "Each item gets its own due date. The routine becomes due when the earliest item is due."
                : "The routine becomes due when the earliest checklist item is due."
        case .fixedInterval, .softInterval, .oneOff:
            return ""
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
        case .intervalDays: return "Repeat after a fixed number of days, weeks, or months."
        case .dailyTime: return "Repeat every day at a specific time."
        case .weekly:
            return includesOptionalExactTimeDetail
                ? "Repeat on the same weekday each week, with an optional exact time."
                : "Repeat on the same weekday each week."
        case .monthlyDay:
            return includesOptionalExactTimeDetail
                ? "Repeat on the same calendar day each month, with an optional exact time."
                : "Repeat on the same calendar day each month."
        }
    }

    var autoAssumeDailyDoneHelpText: String {
        if canAutoAssumeDailyDone {
            return "Show this simple daily routine as assumed done by default. You can still confirm it or mark it not done later."
        }
        return "Available only for simple daily routines without steps or checklist items."
    }

    var weekdayOptions: [(id: Int, name: String)] {
        Calendar.current.weekdaySymbols.enumerated().map { (id: $0.offset + 1, name: $0.element) }
    }

    var weeklyRecurrenceSummary: String {
        "Due every \(Self.weekdayName(for: recurrenceWeekday))."
    }

    func weeklyRecurrenceTimeHelpText(explicitTimeText: String? = nil) -> String {
        if recurrenceHasExplicitTime {
            guard let explicitTimeText else { return weeklyRecurrenceSummary }
            return "Due every \(Self.weekdayName(for: recurrenceWeekday)) at \(explicitTimeText)."
        }
        return "Optional. Leave this off to keep the routine due any time on \(Self.weekdayName(for: recurrenceWeekday))."
    }

    var monthlyRecurrenceSummary: String {
        "Due on the \(Self.ordinalDay(recurrenceDayOfMonth)) of each month."
    }

    func monthlyRecurrenceTimeHelpText(explicitTimeText: String? = nil) -> String {
        if recurrenceHasExplicitTime {
            guard let explicitTimeText else { return monthlyRecurrenceSummary }
            return "Due on the \(Self.ordinalDay(recurrenceDayOfMonth)) of each month at \(explicitTimeText)."
        }
        return "Optional. Leave this off to keep the routine due any time on the \(Self.ordinalDay(recurrenceDayOfMonth)) of each month."
    }

    static func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        return symbols[min(max(weekday - 1, 0), symbols.count - 1)]
    }

    static func ordinalDay(_ day: Int) -> String {
        let resolvedDay = min(max(day, 1), 31)
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

    static func stepperLabel(unit: TaskFormFrequencyUnit, value: Int) -> String {
        if value == 1 {
            return "Every \(unit.singularLabel)"
        }
        return "Every \(value) \(unit.singularLabel)s"
    }

    static func checklistIntervalLabel(for days: Int) -> String {
        days == 1 ? "Runs out in 1 day" : "Runs out in \(days) days"
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
