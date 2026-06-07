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

enum TaskFormTimingMode: String, CaseIterable, Equatable, Identifiable, Sendable {
    case none = "Any time"
    case exact = "At time"
    case range = "Window"

    var id: String { rawValue }
}

enum TaskFormCompactSection: Hashable, Sendable {
    case name
    case taskType
    case emoji
    case color
    case notes
    case voiceNote
    case link
    case deadline
    case reminder
    case importanceUrgency
    case pressure
    case estimation
    case image
    case attachment
    case tags
    case goals
    case relationships
    case scheduleType
    case steps
    case checklist
    case place
    case repeatPattern
    case delete

    static let defaultOrder: [TaskFormCompactSection] = [
        .name,
        .taskType,
        .emoji,
        .color,
        .notes,
        .voiceNote,
        .link,
        .deadline,
        .reminder,
        .importanceUrgency,
        .pressure,
        .estimation,
        .image,
        .attachment,
        .tags,
        .goals,
        .relationships,
        .scheduleType,
        .steps,
        .checklist,
        .place,
        .repeatPattern,
        .delete
    ]
}

struct TaskFormPresentation {
    let taskType: RoutineTaskType
    let scheduleMode: RoutineScheduleMode
    let recurrenceKind: RoutineRecurrenceRule.Kind
    let recurrenceHasExplicitTime: Bool
    var recurrenceHasTimeRange: Bool = false
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
        scheduleMode.isStandardRoutineMode || scheduleMode == .oneOff
    }

    var showsRepeatControls: Bool {
        scheduleMode.showsRoutineRepeatControls
    }

    var showsChecklistTimingControls: Bool {
        taskType == .routine && scheduleMode.routineFinishMode == .checklist
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
        case .routine: return "Repeats on a schedule and stays in your rotation."
        case .todo: return "Happens once. Use a deadline instead of repeat settings."
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
        "Add as many websites as you need. URLs without a scheme will use https."
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
        case .fixedInterval: return "One scheduled routine. Mark it done once, or advance its steps."
        case .softInterval: return "Always visible. Highlight it again after enough time has passed."
        case .fixedIntervalChecklist: return "One scheduled routine that finishes after every checklist item is done."
        case .softIntervalChecklist: return "Always visible. Finish it by completing every checklist item."
        case .derivedFromChecklist: return "Checklist items have their own timing; the earliest due item drives the routine."
        case .softDerivedFromChecklist: return "Checklist items have their own timing, without turning the routine overdue."
        case .oneOff: return "This task does not repeat."
        }
    }

    var scheduleBehaviorDescription: String {
        scheduleMode.scheduleBehavior.explanation
    }

    var routineFormatDescription: String {
        switch scheduleMode.routineFormat {
        case .standard: return "Mark it done once, or advance its steps."
        case .checklist: return "The routine is done when every checklist item is completed."
        case .runout: return "Checklist items have their own timing; the earliest due item drives the routine."
        }
    }

    var routineFinishDescription: String {
        switch scheduleMode.routineFinishMode {
        case .standard:
            return "Mark it done once, or advance its steps."
        case .checklist:
            return "Finish with checklist items; choose their cadence below."
        }
    }

    var checklistTimingDescription: String {
        switch scheduleMode.checklistTimingMode {
        case .together:
            return "Checklist items follow the routine cadence and finish together."
        case .runout:
            return "Each checklist item has its own timing; the earliest due item drives the routine."
        }
    }

    var stepsSectionDescription: String {
        scheduleMode == .oneOff
            ? "Steps run in order. Leave this empty for a single-step todo."
            : "Steps run in order. Leave this empty for a one-step routine."
    }

    func checklistSectionDescription(includesDerivedChecklistDueDetail: Bool) -> String {
        switch scheduleMode {
        case .fixedIntervalChecklist, .softIntervalChecklist:
            return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist, .softDerivedFromChecklist:
            return includesDerivedChecklistDueDetail
                ? "Each item gets its own due date. The routine becomes due when the earliest item is due."
                : "The routine becomes due when the earliest checklist item is due."
        case .fixedInterval, .softInterval:
            return "Use checklist items for parts you want to tick off before finishing the routine."
        case .oneOff:
            return "Use checklist items for parts you want to tick off before finishing the todo."
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
            return "Due every \(Self.weekdayName(for: recurrenceWeekday)) from \(timeRangeText)."
        }
        if recurrenceHasExplicitTime {
            guard let explicitTimeText else { return weeklyRecurrenceSummary }
            return "Due every \(Self.weekdayName(for: recurrenceWeekday)) at \(explicitTimeText)."
        }
        return "Optional. Leave this off to keep the routine due any time on \(Self.weekdayName(for: recurrenceWeekday))."
    }

    var monthlyRecurrenceSummary: String {
        "Due on the \(Self.ordinalDay(recurrenceDayOfMonth)) of each month."
    }

    func monthlyRecurrenceTimeHelpText(
        explicitTimeText: String? = nil,
        timeRangeText: String? = nil
    ) -> String {
        if recurrenceHasTimeRange {
            guard let timeRangeText else { return monthlyRecurrenceSummary }
            return "Due on the \(Self.ordinalDay(recurrenceDayOfMonth)) of each month from \(timeRangeText)."
        }
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
