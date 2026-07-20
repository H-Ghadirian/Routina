import SwiftUI

enum TaskFormVisibilityMode: Equatable, Sendable {
    case full
    case progressiveCreate
    case progressiveEdit

    var usesProgressiveDisclosure: Bool {
        self != .full
    }
}

struct TaskFormModel {
    // MARK: Name
    var name: Binding<String>
    var nameValidationMessage: String?
    var onApplySmartName: (() -> Void)? = nil

    // MARK: Task Type
    var taskType: Binding<RoutineTaskType>

    // MARK: Emoji
    var emoji: Binding<String>
    var emojiOptions: [String]
    var isEmojiPickerPresented: Binding<Bool>

    // MARK: Notes & Link
    var notes: Binding<String>
    var link: Binding<String>

    // MARK: All Day & Deadline
    var deadlineEnabled: Binding<Bool>
    var deadline: Binding<Date>
    var isAllDay: Binding<Bool> = .constant(false)
    var routineDurationMode: Binding<RoutineDurationMode> = .constant(.oneDay)
    var availabilityStartDate: Binding<Date?> = .constant(nil)
    var availabilityEndDate: Binding<Date?> = .constant(nil)
    var plannedDate: Binding<Date?> = .constant(nil)

    // MARK: Reminder
    var reminderEnabled: Binding<Bool>
    var reminderAt: Binding<Date>
    var reminderEventDate: Date? = nil
    var reminderLeadMinutes: Binding<Int?> = .constant(nil)

    // MARK: Priority matrix
    var importance: Binding<RoutineTaskImportance>
    var urgency: Binding<RoutineTaskUrgency>
    var pressure: Binding<RoutineTaskPressure>

    // MARK: Estimation
    var estimatedDurationMinutes: Binding<Int?>
    var actualDurationMinutes: Binding<Int?>? = nil
    var storyPoints: Binding<Int?>

    // MARK: Image
    var imageData: Data?
    var onImagePicked: (Data?) -> Void
    var onRemoveImage: () -> Void

    // MARK: Voice Note
    var voiceNote: RoutineVoiceNote?
    var onVoiceNoteChanged: (RoutineVoiceNote?) -> Void

    // MARK: File Attachments
    var attachments: [AttachmentItem]
    var onAttachmentPicked: (Data, String) -> Void
    var onRemoveAttachment: (UUID) -> Void

    // MARK: Tags
    var tagDraft: Binding<String>
    var routineTags: [String]
    var availableTags: [String]
    var availableTagSummaries: [RoutineTagSummary] = []
    var relatedTagRules: [RoutineRelatedTagRule] = []
    var tagCounterDisplayMode: TagCounterDisplayMode = .defaultValue
    var onAddTag: () -> Void
    var onRemoveTag: (String) -> Void
    var onToggleTagSelection: (String) -> Void

    // MARK: Goals
    var goalDraft: Binding<String>
    var selectedGoals: [RoutineGoalSummary]
    var availableGoals: [RoutineGoalSummary]
    var onAddGoal: () -> Void
    var onRemoveGoal: (UUID) -> Void
    var onToggleGoalSelection: (RoutineGoalSummary) -> Void

    // MARK: Events
    var selectedEventIDs: [UUID] = []
    var availableEvents: [RoutineEventLinkCandidate] = []
    var onToggleEventSelection: (UUID) -> Void = { _ in }

    // MARK: Relationships
    var relationships: [RoutineTaskRelationship]
    var availableRelationshipTasks: [RoutineTaskRelationshipCandidate]
    var onAddRelationship: (UUID, RoutineTaskRelationshipKind) -> Void
    var onRemoveRelationship: (UUID) -> Void

    // MARK: Schedule
    var scheduleMode: Binding<RoutineScheduleMode>

    // MARK: Steps
    var stepDraft: Binding<String>
    var routineSteps: [RoutineStep]
    var onAddStep: () -> Void
    var onRemoveStep: (UUID) -> Void
    var onMoveStepUp: (UUID) -> Void
    var onMoveStepDown: (UUID) -> Void

    // MARK: Checklist
    var checklistItemDraftTitle: Binding<String>
    var checklistItemDraftInterval: Binding<Int>
    var routineChecklistItems: [RoutineChecklistItem]
    var checklistValidationMessage: String? = nil
    var onAddChecklistItem: () -> Void
    var onRemoveChecklistItem: (UUID) -> Void

    // MARK: Place
    var availablePlaces: [RoutinePlaceSummary]
    var selectedPlaceID: Binding<UUID?>
    var selectedPlaceIDs: Binding<[UUID]> = .constant([])

    // MARK: Recurrence
    var recurrenceKind: Binding<RoutineRecurrenceRule.Kind>
    var recurrenceHasExplicitTime: Binding<Bool>
    var recurrenceHasTimeRange: Binding<Bool> = .constant(false)
    var recurrenceTimeRangeRole: Binding<RoutineTimeRangeRole> = .constant(.availability)
    var recurrenceTimeOfDay: Binding<Date>
    var recurrenceTimeRangeStart: Binding<Date> = .constant(RoutineTimeRange.defaultValue.start.date(on: Date()))
    var recurrenceTimeRangeEnd: Binding<Date> = .constant(RoutineTimeRange.defaultValue.end.date(on: Date()))
    var recurrenceWeekday: Binding<Int>
    var recurrenceDayOfMonth: Binding<Int>
    var recurrenceWeekdays: Binding<[Int]> = .constant([])
    var recurrenceDaysOfMonth: Binding<[Int]> = .constant([])
    var frequencyUnit: Binding<TaskFormFrequencyUnit>
    var frequencyValue: Binding<Int>
    var autoAssumeDailyDone: Binding<Bool> = .constant(false)
    var autoAssumeDoneTimeOfDay: Binding<Date> = .constant(
        RoutineAssumedCompletion.defaultDoneTimeOfDay.date(on: Date())
    )
    var focusModeEnabled: Binding<Bool> = .constant(false)
    var trackingCadenceEnabled: Binding<Bool> = .constant(true)
    var trackingNudgesEnabled: Binding<Bool> = .constant(true)

    // MARK: Color
    var color: Binding<RoutineTaskColor>

    // MARK: Focus
    var nameFocus: FocusState<Bool>.Binding? = nil
    var nameFocusRequestID: Int = 0
    var visibilityMode: TaskFormVisibilityMode = .full
    var onCancel: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    var isSaveDisabled = false

    // MARK: Extras
    var autofocusName: Bool = false
    var onDelete: (() -> Void)? = nil
    // macOS Edit only - Danger Zone pause/resume.
    var pauseResumeAction: (() -> Void)? = nil
    var pauseResumeTitle: String? = nil
    var pauseResumeDescription: String? = nil
    var pauseResumeTint: Color? = nil
}

extension TaskFormModel {
    var primaryKind: Binding<TaskFormPrimaryKind> {
        let taskType = taskType
        return Binding(
            get: {
                taskType.wrappedValue == .record ? .record : .task
            },
            set: { kind in
                switch kind {
                case .record:
                    taskType.wrappedValue = .record
                case .task:
                    if taskType.wrappedValue == .record {
                        taskType.wrappedValue = .todo
                    }
                }
            }
        )
    }

    var taskKind: Binding<TaskFormTaskKind> {
        let taskType = taskType
        return Binding(
            get: {
                taskType.wrappedValue == .routine ? .routine : .todo
            },
            set: { kind in
                taskType.wrappedValue = kind.taskType
            }
        )
    }

    var scheduleBehavior: Binding<RoutineScheduleBehavior> {
        let scheduleMode = scheduleMode
        return Binding(
            get: {
                scheduleMode.wrappedValue.scheduleBehavior
            },
            set: { behavior in
                scheduleMode.wrappedValue = RoutineScheduleMode.routineMode(
                    behavior: behavior,
                    format: scheduleMode.wrappedValue.routineFormat
                )
            }
        )
    }

    var routineFormat: Binding<RoutineFormat> {
        let scheduleMode = scheduleMode
        return Binding(
            get: {
                scheduleMode.wrappedValue.routineFormat
            },
            set: { format in
                scheduleMode.wrappedValue = RoutineScheduleMode.routineMode(
                    behavior: scheduleMode.wrappedValue.scheduleBehavior,
                    format: format
                )
            }
        )
    }

    var routineFinishMode: Binding<RoutineFinishMode> {
        let scheduleMode = scheduleMode
        return Binding(
            get: {
                scheduleMode.wrappedValue.routineFinishMode
            },
            set: { finishMode in
                scheduleMode.wrappedValue = scheduleMode.wrappedValue.replacingRoutineFinishMode(finishMode)
            }
        )
    }

    var checklistTimingMode: Binding<ChecklistTimingMode> {
        let scheduleMode = scheduleMode
        return Binding(
            get: {
                scheduleMode.wrappedValue.checklistTimingMode
            },
            set: { timingMode in
                scheduleMode.wrappedValue = scheduleMode.wrappedValue.replacingChecklistTimingMode(timingMode)
            }
        )
    }

    var repeatBasis: Binding<RoutineRepeatBasis> {
        let recurrenceKind = recurrenceKind
        return Binding(
            get: {
                RoutineRecurrenceRule.Kind.calendarCases.contains(recurrenceKind.wrappedValue)
                    ? .calendar
                    : .interval
            },
            set: { basis in
                recurrenceKind.wrappedValue = recurrenceKind.wrappedValue.replacingRepeatBasis(basis)
            }
        )
    }

    var supportsItemRunoutRepeatType: Bool {
        (taskType.wrappedValue == .routine || taskType.wrappedValue == .record)
            && scheduleMode.wrappedValue.usesRoutineCadence
            && scheduleMode.wrappedValue.routineFinishMode == .checklist
    }

    var routineRepeatTypeCases: [RoutineRepeatType] {
        RoutineRepeatType.cases(
            supportsNoRepeat: taskType.wrappedValue == .record,
            supportsItemRunout: supportsItemRunoutRepeatType
        )
    }

    var routineRepeatType: Binding<RoutineRepeatType> {
        let taskType = taskType
        let scheduleMode = scheduleMode
        let recurrenceKind = recurrenceKind
        let trackingCadenceEnabled = trackingCadenceEnabled

        return Binding(
            get: {
                if taskType.wrappedValue == .record, !trackingCadenceEnabled.wrappedValue {
                    return .none
                }

                if scheduleMode.wrappedValue.isChecklistDrivenMode {
                    return .itemRunout
                }

                return RoutineRecurrenceRule.Kind.calendarCases.contains(recurrenceKind.wrappedValue)
                    ? .calendar
                    : .interval
            },
            set: { repeatType in
                switch repeatType {
                case .none:
                    guard taskType.wrappedValue == .record else { return }
                    trackingCadenceEnabled.wrappedValue = false
                    if scheduleMode.wrappedValue.isChecklistDrivenMode {
                        scheduleMode.wrappedValue = Self.nonRunoutScheduleMode(from: scheduleMode.wrappedValue)
                    }

                case .interval:
                    trackingCadenceEnabled.wrappedValue = true
                    if scheduleMode.wrappedValue.isChecklistDrivenMode {
                        scheduleMode.wrappedValue = Self.nonRunoutScheduleMode(from: scheduleMode.wrappedValue)
                    }
                    recurrenceKind.wrappedValue = recurrenceKind.wrappedValue.replacingRepeatBasis(.interval)

                case .calendar:
                    trackingCadenceEnabled.wrappedValue = true
                    if scheduleMode.wrappedValue.isChecklistDrivenMode {
                        scheduleMode.wrappedValue = Self.nonRunoutScheduleMode(from: scheduleMode.wrappedValue)
                    }
                    recurrenceKind.wrappedValue = recurrenceKind.wrappedValue.replacingRepeatBasis(.calendar)

                case .itemRunout:
                    guard (taskType.wrappedValue == .routine || taskType.wrappedValue == .record),
                          scheduleMode.wrappedValue.usesRoutineCadence,
                          scheduleMode.wrappedValue.routineFinishMode == .checklist
                    else { return }

                    trackingCadenceEnabled.wrappedValue = true
                    if scheduleMode.wrappedValue.taskType == .record {
                        scheduleMode.wrappedValue = .recordDerivedFromChecklist
                    } else {
                        scheduleMode.wrappedValue = RoutineScheduleMode.routineMode(
                            behavior: scheduleMode.wrappedValue.scheduleBehavior,
                            format: .runout
                        )
                    }
                }
            }
        )
    }

    var calendarRecurrenceKind: Binding<RoutineRecurrenceRule.Kind> {
        let recurrenceKind = recurrenceKind
        return Binding(
            get: {
                let currentKind = recurrenceKind.wrappedValue
                return RoutineRecurrenceRule.Kind.calendarCases.contains(currentKind) ? currentKind : .weekly
            },
            set: { kind in
                guard RoutineRecurrenceRule.Kind.calendarCases.contains(kind) else { return }
                recurrenceKind.wrappedValue = kind
            }
        )
    }

    var intervalFrequencyValueBounds: ClosedRange<Int> {
        TaskFormRecurrenceConstraints.frequencyValueBounds(
            scheduleMode: scheduleMode.wrappedValue,
            routineDurationMode: routineDurationMode.wrappedValue,
            recurrenceKind: recurrenceKind.wrappedValue,
            frequencyUnit: frequencyUnit.wrappedValue
        )
    }

    var canAutoAssumeDailyDone: Bool {
        RoutineAssumedCompletion.isEligible(
            scheduleMode: scheduleMode.wrappedValue,
            recurrenceRule: candidateRecurrenceRule,
            trackingCadenceEnabled: scheduleMode.wrappedValue.taskType == .record
                ? trackingCadenceEnabled.wrappedValue
                : true,
            hasSequentialSteps: !routineSteps.isEmpty,
            hasChecklistItems: !routineChecklistItems.isEmpty
        )
    }

    private var candidateRecurrenceRule: RoutineRecurrenceRule {
        let currentScheduleMode = scheduleMode.wrappedValue
        let usesAvailabilityTiming = !isAllDay.wrappedValue
        let timeRange = usesAvailabilityTiming && recurrenceHasTimeRange.wrappedValue
            ? RoutineTimeRange(
                start: RoutineTimeOfDay.from(recurrenceTimeRangeStart.wrappedValue),
                end: RoutineTimeOfDay.from(recurrenceTimeRangeEnd.wrappedValue)
            )
            : nil
        let timeOfDay = usesAvailabilityTiming && recurrenceHasExplicitTime.wrappedValue
            ? RoutineTimeOfDay.from(recurrenceTimeOfDay.wrappedValue)
            : nil

        switch currentScheduleMode.taskType {
        case .todo:
            return .interval(days: 1, at: timeOfDay, timeRange: timeRange)
        case .routine, .record:
            break
        }

        guard !currentScheduleMode.isChecklistDrivenMode else {
            return .interval(days: max(effectiveIntervalDays, 1))
        }

        switch recurrenceKind.wrappedValue {
        case .intervalDays:
            return .interval(days: max(effectiveIntervalDays, 1), at: timeOfDay, timeRange: timeRange)
        case .dailyTime:
            if let timeRange {
                return .daily(in: timeRange)
            }
            return RoutineRecurrenceRule(kind: .dailyTime, timeOfDay: timeOfDay)
        case .weekly:
            return .weekly(on: effectiveRecurrenceWeekdays, at: timeOfDay, timeRange: timeRange)
        case .monthlyDay:
            return .monthly(on: effectiveRecurrenceDaysOfMonth, at: timeOfDay, timeRange: timeRange)
        }
    }

    private var effectiveIntervalDays: Int {
        TaskFormRecurrenceConstraints.effectiveIntervalDays(
            value: frequencyValue.wrappedValue,
            unit: frequencyUnit.wrappedValue,
            scheduleMode: scheduleMode.wrappedValue,
            routineDurationMode: routineDurationMode.wrappedValue,
            recurrenceKind: recurrenceKind.wrappedValue
        )
    }

    var suggestedRelatedTags: [String] {
        RoutineTagRelations.relatedTags(
            for: routineTags,
            rules: relatedTagRules,
            availableTags: availableTags
        )
    }

    var tagAutocompleteSuggestion: String? {
        RoutineTag.autocompleteSuggestion(
            for: tagDraft.wrappedValue,
            availableTags: availableTags,
            selectedTags: routineTags
        )
    }

    func acceptTagAutocompleteSuggestion() {
        guard let suggestion = tagAutocompleteSuggestion else { return }
        tagDraft.wrappedValue = RoutineTag.acceptingAutocompleteSuggestion(
            suggestion,
            in: tagDraft.wrappedValue
        )
    }

    func visibleCompactSections(isShowingMoreDetails: Bool) -> [TaskFormCompactSection] {
        let availableSections = availableCompactSections
        guard visibilityMode.usesProgressiveDisclosure, !isShowingMoreDetails else {
            return availableSections
        }

        let primarySections = progressivePrimaryCompactSections
        let populatedSections = populatedCompactSections
        return availableSections.filter {
            primarySections.contains($0) || populatedSections.contains($0)
        }
    }

    var allowsOptionalChecklistReveal: Bool {
        taskType.wrappedValue == .todo || taskType.wrappedValue == .record
    }

    var shouldShowChecklistSection: Bool {
        allowsOptionalChecklistReveal
            || hasChecklistSectionContent
            || scheduleMode.wrappedValue.isRoutineModeRequiringChecklistItems
    }

    var supportsExactDateReminder: Bool {
        taskType.wrappedValue == .todo
    }

    var supportsPlanning: Bool {
        switch taskType.wrappedValue {
        case .todo:
            return true
        case .routine:
            return !isDailyRoutineDraft
        case .record:
            return trackingCadenceEnabled.wrappedValue
        }
    }

    private var availableCompactSections: [TaskFormCompactSection] {
        TaskFormCompactSection.defaultOrder.filter { section in
            switch section {
            case .steps:
                return scheduleMode.wrappedValue.isStandardRoutineMode
                    || scheduleMode.wrappedValue == .oneOff
                    || scheduleMode.wrappedValue == .record
            case .checklist:
                return shouldShowChecklistSection
            case .deadline:
                return taskType.wrappedValue == .todo
            case .reminder:
                return supportsExactDateReminder
            case .planning:
                return supportsPlanning
            default:
                return true
            }
        }
    }

    private var isDailyRoutineDraft: Bool {
        let currentScheduleMode = scheduleMode.wrappedValue
        guard currentScheduleMode.usesRoutineCadence else { return false }
        if currentScheduleMode.isChecklistDrivenMode {
            return RoutineTaskDailyRoutineSupport.hasDailyRunoutChecklistItem(candidateChecklistItems)
        }
        switch recurrenceKind.wrappedValue {
        case .dailyTime:
            return true
        case .intervalDays:
            return frequencyUnit.wrappedValue == .day && frequencyValue.wrappedValue <= 1
        case .weekly, .monthlyDay:
            return false
        }
    }

    private var candidateChecklistItems: [RoutineChecklistItem] {
        if let pendingTitle = RoutineChecklistItem.normalizedTitle(checklistItemDraftTitle.wrappedValue) {
            return RoutineChecklistItem.sanitized(
                routineChecklistItems + [
                    RoutineChecklistItem(
                        title: pendingTitle,
                        intervalDays: scheduleMode.wrappedValue.normalizedChecklistItemIntervalDays(
                            checklistItemDraftInterval.wrappedValue
                        )
                    )
                ],
                for: scheduleMode.wrappedValue
            )
        }
        return RoutineChecklistItem.sanitized(routineChecklistItems, for: scheduleMode.wrappedValue)
    }

    private var hasChecklistSectionContent: Bool {
        !routineChecklistItems.isEmpty || hasText(checklistItemDraftTitle.wrappedValue)
    }

    private var progressivePrimaryCompactSections: Set<TaskFormCompactSection> {
        var sections: Set<TaskFormCompactSection> = [
            .name,
            .taskType,
            .deadline
        ]

        if visibilityMode == .progressiveCreate {
            sections.insert(.goals)
        }

        if supportsExactDateReminder {
            sections.insert(.reminder)
        }

        if scheduleMode.wrappedValue.taskType == .routine || scheduleMode.wrappedValue.taskType == .record {
            sections.insert(.scheduleType)
        }

        if scheduleMode.wrappedValue.usesRoutineCadence
            && (scheduleMode.wrappedValue.showsRoutineRepeatControls
                || scheduleMode.wrappedValue.routineFinishMode == .checklist) {
            sections.insert(.repeatPattern)
        }

        return sections
    }

    private var populatedCompactSections: Set<TaskFormCompactSection> {
        var sections = Set<TaskFormCompactSection>()

        if color.wrappedValue != .none {
            sections.insert(.color)
        }
        if hasText(notes.wrappedValue) {
            sections.insert(.notes)
        }
        if voiceNote != nil {
            sections.insert(.voiceNote)
        }
        if hasText(link.wrappedValue) {
            sections.insert(.link)
        }
        if supportsPlanning, plannedDate.wrappedValue != nil {
            sections.insert(.planning)
        }
        if importance.wrappedValue != .level2 || urgency.wrappedValue != .level2 {
            sections.insert(.importanceUrgency)
        }
        if pressure.wrappedValue != .none {
            sections.insert(.pressure)
        }
        if estimatedDurationMinutes.wrappedValue != nil
            || actualDurationMinutes?.wrappedValue != nil
            || storyPoints.wrappedValue != nil
            || focusModeEnabled.wrappedValue {
            sections.insert(.estimation)
        }
        if imageData != nil {
            sections.insert(.image)
        }
        if !attachments.isEmpty {
            sections.insert(.attachment)
        }
        if !routineTags.isEmpty || hasText(tagDraft.wrappedValue) {
            sections.insert(.tags)
        }
        if !selectedGoals.isEmpty || hasText(goalDraft.wrappedValue) {
            sections.insert(.goals)
        }
        if !selectedEventIDs.isEmpty {
            sections.insert(.events)
        }
        if !relationships.isEmpty {
            sections.insert(.relationships)
        }
        if !routineSteps.isEmpty || hasText(stepDraft.wrappedValue) {
            sections.insert(.steps)
        }
        if !routineChecklistItems.isEmpty
            || hasText(checklistItemDraftTitle.wrappedValue)
            || scheduleMode.wrappedValue.isRoutineModeRequiringChecklistItems {
            sections.insert(.checklist)
        }
        if !selectedPlaceIDsValue.isEmpty {
            sections.insert(.place)
        }

        return sections
    }

    private func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func nonRunoutScheduleMode(from scheduleMode: RoutineScheduleMode) -> RoutineScheduleMode {
        let fallbackFormat: RoutineFormat = scheduleMode.routineFinishMode == .checklist ? .checklist : .standard
        if scheduleMode.taskType == .record {
            return fallbackFormat == .checklist ? .recordChecklist : .record
        }
        return RoutineScheduleMode.routineMode(
            behavior: scheduleMode.scheduleBehavior,
            format: fallbackFormat
        )
    }
}

extension TaskFormModel {
    var effectiveRecurrenceWeekdays: [Int] {
        let selectedWeekdays = Array(Set(recurrenceWeekdays.wrappedValue.map { min(max($0, 1), 7) })).sorted()
        return selectedWeekdays.isEmpty ? [min(max(recurrenceWeekday.wrappedValue, 1), 7)] : selectedWeekdays
    }

    var effectiveRecurrenceDaysOfMonth: [Int] {
        let selectedDays = Array(Set(recurrenceDaysOfMonth.wrappedValue.map { min(max($0, 1), 31) })).sorted()
        return selectedDays.isEmpty ? [min(max(recurrenceDayOfMonth.wrappedValue, 1), 31)] : selectedDays
    }

    func setRecurrenceWeekdays(_ weekdays: [Int]) {
        let selectedWeekdays = Array(Set(weekdays.map { min(max($0, 1), 7) })).sorted()
        recurrenceWeekdays.wrappedValue = selectedWeekdays
    }

    func setRecurrenceDaysOfMonth(_ daysOfMonth: [Int]) {
        let selectedDays = Array(Set(daysOfMonth.map { min(max($0, 1), 31) })).sorted()
        recurrenceDaysOfMonth.wrappedValue = selectedDays
    }

    var selectedEventCandidates: [RoutineEventLinkCandidate] {
        RoutineEventLinkCandidate.selectedCandidates(
            for: selectedEventIDs,
            in: availableEvents
        )
    }
}

extension TaskFormModel {
    var selectedPlaceIDsValue: [UUID] {
        let selectedIDs = RoutinePlaceIDStorage.sanitized(selectedPlaceIDs.wrappedValue)
        if !selectedIDs.isEmpty {
            return selectedIDs
        }
        return selectedPlaceID.wrappedValue.map { [$0] } ?? []
    }

    var selectedPlaceSummaries: [RoutinePlaceSummary] {
        let placesByID = Dictionary(availablePlaces.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return selectedPlaceIDsValue.compactMap { placesByID[$0] }
    }

    var selectedPlaceMenuTitle: String {
        let summaries = selectedPlaceSummaries
        switch summaries.count {
        case 0:
            return "Anywhere"
        case 1:
            return summaries[0].name
        default:
            return "\(summaries[0].name) + \(summaries.count - 1)"
        }
    }

    func setSelectedPlaceIDs(_ placeIDs: [UUID]) {
        let sanitizedPlaceIDs = RoutinePlaceIDStorage.sanitized(placeIDs)
        selectedPlaceIDs.wrappedValue = sanitizedPlaceIDs
        selectedPlaceID.wrappedValue = sanitizedPlaceIDs.first
    }

    func toggleSelectedPlace(_ placeID: UUID) {
        var selectedIDs = selectedPlaceIDsValue
        if selectedIDs.contains(placeID) {
            selectedIDs.removeAll { $0 == placeID }
        } else {
            selectedIDs.append(placeID)
        }
        setSelectedPlaceIDs(selectedIDs)
    }
}
