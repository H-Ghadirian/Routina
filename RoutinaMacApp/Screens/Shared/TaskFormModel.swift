import SwiftUI

enum TaskFormFrequencyUnit: String, CaseIterable, Equatable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var singularLabel: String { rawValue.lowercased() }
}

struct TaskFormModel {
    // MARK: Name
    var name: Binding<String>
    var nameValidationMessage: String?

    // MARK: Task Type
    var taskType: Binding<RoutineTaskType>

    // MARK: Emoji
    var emoji: Binding<String>
    var emojiOptions: [String]
    var isEmojiPickerPresented: Binding<Bool>

    // MARK: Notes & Link
    var notes: Binding<String>
    var link: Binding<String>

    // MARK: Deadline (todo only)
    var deadlineEnabled: Binding<Bool>
    var deadline: Binding<Date>

    // MARK: Reminder
    var reminderEnabled: Binding<Bool>
    var reminderAt: Binding<Date>

    // MARK: Priority matrix
    var importance: Binding<RoutineTaskImportance>
    var urgency: Binding<RoutineTaskUrgency>
    var pressure: Binding<RoutineTaskPressure>

    // MARK: Estimation
    var estimatedDurationMinutes: Binding<Int?>
    var storyPoints: Binding<Int?>

    // MARK: Image
    var imageData: Data?
    var onImagePicked: (Data?) -> Void
    var onRemoveImage: () -> Void

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
    var recurrenceTimeOfDay: Binding<Date>
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

    // MARK: Extras
    var autofocusName: Bool = false
    var onDelete: (() -> Void)? = nil
    // macOS Edit only — Danger Zone pause/resume
    var pauseResumeAction: (() -> Void)? = nil
    var pauseResumeTitle: String? = nil
    var pauseResumeDescription: String? = nil
    var pauseResumeTint: Color? = nil
}

extension TaskFormModel {
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
}
