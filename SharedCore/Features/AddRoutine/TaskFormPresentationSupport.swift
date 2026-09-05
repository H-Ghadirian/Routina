import Foundation

enum TaskFormFrequencyUnit: String, Codable, CaseIterable, Equatable, Sendable {
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

enum TaskFormCreationKind: String, CaseIterable, Equatable, Identifiable, Sendable {
    case oneTime = "One-time"
    case repeating = "Repeating"

    var id: String { rawValue }
}

enum TaskFormTimingMode: String, CaseIterable, Equatable, Identifiable, Sendable {
    case none = "Any time"
    case allDay = "All-day"
    case exact = "At time"
    case timeBlock = "Time block"
    case availableWindow = "Available window"

    var id: String { rawValue }

    var usesTimeRange: Bool {
        switch self {
        case .timeBlock, .availableWindow:
            return true
        case .none, .allDay, .exact:
            return false
        }
    }

    var timeRangeRole: RoutineTimeRangeRole? {
        switch self {
        case .timeBlock:
            return .scheduledBlock
        case .availableWindow:
            return .availability
        case .none, .allDay, .exact:
            return nil
        }
    }

    /// Creates the first range shown when a person changes an exact time into
    /// a range. The exact time remains the meaningful anchor and the default
    /// range duration is retained from the standard 07:00–10:00 range.
    static func timeRangeInheritingExactTime(
        _ exactTime: RoutineTimeOfDay
    ) -> RoutineTimeRange {
        let defaultDurationMinutes =
            RoutineTimeRange.defaultValue.end.minutesFromStartOfDay
            - RoutineTimeRange.defaultValue.start.minutesFromStartOfDay
        return RoutineTimeRange(
            start: exactTime,
            end: exactTime.addingMinutes(defaultDurationMinutes)
        )
    }

    func timeRangeHelpText(startTimeText: String, endTimeText: String) -> String? {
        switch self {
        case .timeBlock:
            return "Reserve the full time from \(startTimeText) to \(endTimeText)"
        case .availableWindow:
            return "Can be scheduled anytime between \(startTimeText) and \(endTimeText)"
        case .none, .allDay, .exact:
            return nil
        }
    }

    static func cases(for _: RoutineTaskType) -> [Self] {
        allCases
    }
}

enum TaskFormDateAvailabilityMode: String, CaseIterable, Equatable, Identifiable, Sendable {
    case none = "Any date"
    case exact = "At date"
    case range = "Date window"

    var id: String { rawValue }
}

enum TaskFormSidebarPathPresentation {
    static func automaticPathTitles(
        customTaskSectionID: UUID?,
        sidebarPathTitles: [String]?
    ) -> [String]? {
        guard customTaskSectionID == nil,
            breadcrumb(from: sidebarPathTitles) != nil
        else {
            return nil
        }
        return sidebarPathTitles
    }

    static func title(
        explicitPathTitles: [String]?,
        automaticPathTitles: [String]?
    ) -> String {
        if let explicitPath = breadcrumb(from: explicitPathTitles) {
            return explicitPath
        }
        if let automaticPath = breadcrumb(from: automaticPathTitles) {
            return "\(automaticPath) (Automatic)"
        }
        return "Automatic"
    }

    private static func breadcrumb(from titles: [String]?) -> String? {
        let nonemptyTitles =
            titles?.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } ?? []
        guard !nonemptyTitles.isEmpty else { return nil }
        return nonemptyTitles.joined(separator: " › ")
    }
}

enum TaskFormFixedSchedulePresentation {
    static func startIncludesTime(
        frequency: RoutineAdvancedRecurrenceRule.Frequency,
        availabilityUsesWindow: Bool
    ) -> Bool {
        frequency == .hourly && !availabilityUsesWindow
    }

    static func inlinesSingleOccurrenceTime(
        isDesktop: Bool,
        frequency: RoutineAdvancedRecurrenceRule.Frequency,
        occurrenceTimeCount: Int
    ) -> Bool {
        guard isDesktop, occurrenceTimeCount == 1 else { return false }
        switch frequency {
        case .weekly, .monthly, .yearly:
            return true
        case .hourly, .daily:
            return false
        }
    }

    static func summary(
        for draft: RoutineRecurrenceDraft,
        calendar: Calendar = .current
    ) -> String {
        guard draft.usesFixedScheduleDetails else { return "Default" }
        guard let startDate = draft.startDate else {
            return draft.requiresFixedScheduleDetails ? "Required" : "Fixed schedule"
        }

        let includesTime = startIncludesTime(
            frequency: draft.frequency,
            availabilityUsesWindow: draft.availability.usesWindow
        )
        let startText = formatted(
            startDate,
            includesTime: includesTime,
            timeZoneIdentifier: draft.timeZoneIdentifier,
            calendar: calendar
        )
        return "Starts \(startText) · \(endSummary(for: draft, calendar: calendar))"
    }

    private static func endSummary(
        for draft: RoutineRecurrenceDraft,
        calendar: Calendar
    ) -> String {
        switch draft.endMode {
        case .never:
            return "Never ends"
        case .onDate:
            let endDateText = formatted(
                draft.endDate,
                includesTime: false,
                timeZoneIdentifier: draft.timeZoneIdentifier,
                calendar: calendar
            )
            return "Ends \(endDateText)"
        case .afterCount:
            return "\(draft.occurrenceCount) occurrences"
        }
    }

    private static func formatted(
        _ date: Date,
        includesTime: Bool,
        timeZoneIdentifier: String?,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone =
            TimeZone(identifier: timeZoneIdentifier ?? "")
            ?? calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = includesTime ? .short : .none
        return formatter.string(from: date)
    }
}

enum RoutineRepeatType: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case none = "None"
    case interval = "Interval"
    case calendar = "Calendar"
    case itemRunout = "Item runout"

    var id: String { rawValue }

    static func cases(supportsNoRepeat: Bool, supportsItemRunout: Bool) -> [Self] {
        var cases: [Self] = supportsNoRepeat ? [.none, .interval, .calendar] : [.interval, .calendar]
        if supportsItemRunout {
            cases.append(.itemRunout)
        }
        return cases
    }
}

enum TaskFormRecurrenceConstraints {
    static let defaultFrequencyValueBounds = 1...365

    static func frequencyValueBounds(
        scheduleMode: RoutineScheduleMode,
        routineDurationMode: RoutineDurationMode,
        recurrenceKind: RoutineRecurrenceRule.Kind,
        frequencyUnit: TaskFormFrequencyUnit
    ) -> ClosedRange<Int> {
        let lowerBound =
            scheduleMode != .oneOff
                && routineDurationMode == .multiDay
                && recurrenceKind == .intervalDays
                && frequencyUnit == .day
            ? 2
            : defaultFrequencyValueBounds.lowerBound
        return lowerBound...defaultFrequencyValueBounds.upperBound
    }

    static func clampedFrequencyValue(
        _ value: Int,
        scheduleMode: RoutineScheduleMode,
        routineDurationMode: RoutineDurationMode,
        recurrenceKind: RoutineRecurrenceRule.Kind,
        frequencyUnit: TaskFormFrequencyUnit
    ) -> Int {
        let bounds = frequencyValueBounds(
            scheduleMode: scheduleMode,
            routineDurationMode: routineDurationMode,
            recurrenceKind: recurrenceKind,
            frequencyUnit: frequencyUnit
        )
        return min(max(value, bounds.lowerBound), bounds.upperBound)
    }

    static func effectiveIntervalDays(
        value: Int,
        unit: TaskFormFrequencyUnit,
        scheduleMode: RoutineScheduleMode,
        routineDurationMode: RoutineDurationMode,
        recurrenceKind: RoutineRecurrenceRule.Kind
    ) -> Int {
        let value = clampedFrequencyValue(
            value,
            scheduleMode: scheduleMode,
            routineDurationMode: routineDurationMode,
            recurrenceKind: recurrenceKind,
            frequencyUnit: unit
        )
        return value * unit.daysMultiplier
    }
}

enum TaskFormCompactSection: Hashable, Sendable {
    case name
    case taskType
    case taskDescription
    case emoji
    case color
    case notes
    case voiceNote
    case link
    case planning
    case deadline
    case reminder
    case taskLadderValues
    case estimation
    case image
    case attachment
    case organization
    case goals
    case events
    case relationships
    case scheduleType
    case steps
    case checklist
    case place
    case destination
    case repeatPattern
    case delete

    static let defaultOrder: [TaskFormCompactSection] = [
        .name,
        .taskType,
        .deadline,
        .reminder,
        .scheduleType,
        .repeatPattern,
        .taskLadderValues,
        .organization,
        .taskDescription,
        .emoji,
        .color,
        .planning,
        .estimation,
        .place,
        .destination,
        .goals,
        .events,
        .relationships,
        .steps,
        .checklist,
        .notes,
        .voiceNote,
        .link,
        .image,
        .attachment,
        .delete,
    ]
}

enum TaskFormEffortPresentation {
    static let sectionTitle = "Effort"

    static let timeEstimateTitle = "Time estimate"
    static let timeEstimateDetail = "Planned duration"
    static let actualTimeTitle = "Actual time"
    static let actualTimeDetail = "Recorded duration"
    static let storyPointsTitle = "Story points"
    static let storyPointsDetail = "Relative size"
    static let focusTimerTitle = "Focus timer"
    static let focusTimerDetail = "Attention-session tracking"

    static func timeEstimateActionTitle(minutes: Int?) -> String {
        minutes == nil ? "Set" : "Remove"
    }

    static func actualTimeActionTitle(minutes: Int?) -> String {
        minutes == nil ? "Log" : "Clear"
    }

    static func storyPointsActionTitle(points: Int?) -> String {
        points == nil ? "Set" : "Remove"
    }
}
