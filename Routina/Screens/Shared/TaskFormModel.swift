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

    // MARK: Priority matrix
    var importance: Binding<RoutineTaskImportance>
    var urgency: Binding<RoutineTaskUrgency>

    // MARK: Image
    var imageData: Data?
    var onImagePicked: (Data?) -> Void
    var onRemoveImage: () -> Void

    // MARK: Tags
    var tagDraft: Binding<String>
    var routineTags: [String]
    var availableTags: [String]
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
    var recurrenceTimeOfDay: Binding<Date>
    var recurrenceWeekday: Binding<Int>
    var recurrenceDayOfMonth: Binding<Int>
    var frequencyUnit: Binding<TaskFormFrequencyUnit>
    var frequencyValue: Binding<Int>

    // MARK: Extras
    var autofocusName: Bool = false
    var onDelete: (() -> Void)? = nil
}
