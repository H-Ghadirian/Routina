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
    var onAddChecklistItem: () -> Void
    var onRemoveChecklistItem: (UUID) -> Void

    // MARK: Place
    var availablePlaces: [RoutinePlaceSummary]
    var selectedPlaceID: Binding<UUID?>

    // MARK: Recurrence
    var recurrenceKind: Binding<RoutineRecurrenceRule.Kind>
    var recurrenceHasExplicitTime: Binding<Bool>
    var recurrenceHasTimeRange: Binding<Bool> = .constant(false)
    var recurrenceTimeOfDay: Binding<Date>
    var recurrenceTimeRangeStart: Binding<Date> = .constant(RoutineTimeRange.defaultValue.start.date(on: Date()))
    var recurrenceTimeRangeEnd: Binding<Date> = .constant(RoutineTimeRange.defaultValue.end.date(on: Date()))
    var recurrenceWeekday: Binding<Int>
    var recurrenceDayOfMonth: Binding<Int>
    var frequencyUnit: Binding<TaskFormFrequencyUnit>
    var frequencyValue: Binding<Int>
    var autoAssumeDailyDone: Binding<Bool> = .constant(false)
    var canAutoAssumeDailyDone: Bool = false
    var focusModeEnabled: Binding<Bool> = .constant(false)

    // MARK: Color
    var color: Binding<RoutineTaskColor>

    // MARK: Focus
    var nameFocus: FocusState<Bool>.Binding? = nil
    var nameFocusRequestID: Int = 0
    var visibilityMode: TaskFormVisibilityMode = .full

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
                recurrenceKind.wrappedValue.repeatBasis
            },
            set: { basis in
                recurrenceKind.wrappedValue = recurrenceKind.wrappedValue.replacingRepeatBasis(basis)
            }
        )
    }

    var calendarRecurrenceKind: Binding<RoutineRecurrenceRule.Kind> {
        let recurrenceKind = recurrenceKind
        return Binding(
            get: {
                let currentKind = recurrenceKind.wrappedValue
                return currentKind.repeatBasis == .calendar ? currentKind : .dailyTime
            },
            set: { kind in
                guard kind.repeatBasis == .calendar else { return }
                recurrenceKind.wrappedValue = kind
            }
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
        taskType.wrappedValue == .todo
    }

    var shouldShowChecklistSection: Bool {
        allowsOptionalChecklistReveal
            || hasChecklistSectionContent
            || scheduleMode.wrappedValue.isRoutineModeRequiringChecklistItems
    }

    private var availableCompactSections: [TaskFormCompactSection] {
        TaskFormCompactSection.defaultOrder.filter { section in
            section != .checklist || shouldShowChecklistSection
        }
    }

    private var hasChecklistSectionContent: Bool {
        !routineChecklistItems.isEmpty || hasText(checklistItemDraftTitle.wrappedValue)
    }

    private var progressivePrimaryCompactSections: Set<TaskFormCompactSection> {
        var sections: Set<TaskFormCompactSection> = [
            .name,
            .taskType,
            .deadline,
            .reminder
        ]

        if scheduleMode.wrappedValue.taskType == .routine {
            sections.insert(.scheduleType)
        }

        if scheduleMode.wrappedValue.showsRoutineRepeatControls
            || scheduleMode.wrappedValue.routineFinishMode == .checklist {
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
        if selectedPlaceID.wrappedValue != nil {
            sections.insert(.place)
        }

        return sections
    }

    private func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
