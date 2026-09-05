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
    var taskLadderGroupEnabled: Binding<Bool> = .constant(false)
    var canDisableTaskLadderGroup: Bool = true

    // MARK: Sidebar Path
    var customTaskSectionID: Binding<UUID?> = .constant(nil)
    var automaticPathTitles: [String]? = nil

    // MARK: Emoji
    var emoji: Binding<String>
    var emojiOptions: [String]
    var isEmojiPickerPresented: Binding<Bool>

    // MARK: Description, Notes & Link
    var taskDescription: Binding<String> = .constant("")
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

    // MARK: Importance, Urgency & Effort
    var importance: Binding<RoutineTaskImportance>
    var urgency: Binding<RoutineTaskUrgency>
    var pressure: Binding<RoutineTaskPressure>
    var temporalWeightRule: Binding<RoutineTaskTemporalWeightRule?> = .constant(nil)
    var taskLadderEntryWindow: Binding<RoutineTaskLadderEntryWindow> = .constant(.throughoutCycle)
    var thinkingNeeded: Binding<RoutineTaskThinkingNeeded> = .constant(.none)

    // MARK: Effort
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

    // MARK: Flags
    var flagDraft: Binding<String> = .constant("")
    var routineFlags: [String] = []
    var availableFlags: [String] = []
    var onAddFlag: () -> Void = {}
    var onRemoveFlag: (String) -> Void = { _ in }
    var onToggleFlagSelection: (String) -> Void = { _ in }

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
    var onCreateLinkedTask: ((RoutineTaskRelationshipKind) -> Void)? = nil

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

    // MARK: Destination
    var destinationAddress: Binding<String> = .constant("")
    var destinationCoordinate: Binding<LocationCoordinate?> = .constant(nil)

    // MARK: Recurrence
    var recurrenceDraft: Binding<RoutineRecurrenceDraft> = .constant(
        RoutineRecurrenceDraft(cadence: .none)
    )
    var recurrenceEditorMode: Binding<RoutineRecurrenceEditorMode> = .constant(.simple)
    var advancedRecurrenceRule: Binding<RoutineAdvancedRecurrenceRule> = .constant(
        RoutineAdvancedRecurrenceRule()
    )
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
    var autoAssumeDoneEnabledByFlag: Bool = false
    var flagSelectionValidationMessage: String? = nil
    var hidesAssumedDoneCalendarBlock: Binding<Bool> = .constant(false)
    var autoAssumeDoneTimeOfDay: Binding<Date> = .constant(
        RoutineAssumedCompletion.defaultDoneTimeOfDay.date(on: Date())
    )
    var focusModeEnabled: Binding<Bool> = .constant(false)
    var focusSessionCount = 0
    var cadenceEnabled: Binding<Bool> = .constant(true)
    var nudgesEnabled: Binding<Bool> = .constant(true)

    // MARK: Color
    var color: Binding<RoutineTaskColor>

    // MARK: Focus
    var nameFocus: FocusState<Bool>.Binding? = nil
    var nameFocusRequestID: Int = 0
    var visibilityMode: TaskFormVisibilityMode = .full
    var initiallyRevealedCompactSections: Set<TaskFormCompactSection> = []
    var onCancel: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    var isSaveDisabled = false
    var isSaving = false

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
    var hasFocusSessions: Bool {
        focusSessionCount > 0
    }

    var focusSessionCountText: String {
        focusSessionCount == 1 ? "1 session" : "\(focusSessionCount) sessions"
    }

    var hasEstimatedDuration: Bool {
        estimatedDurationMinutes.wrappedValue != nil
    }

    var estimatedDurationValue: Binding<Int> {
        let estimatedDurationMinutes = estimatedDurationMinutes
        return Binding(
            get: { max(estimatedDurationMinutes.wrappedValue ?? 30, 5) },
            set: {
                estimatedDurationMinutes.wrappedValue =
                    RoutineTask.sanitizedEstimatedDurationMinutes(max($0, 5))
            }
        )
    }

    func addEstimatedDuration() {
        estimatedDurationMinutes.wrappedValue = estimatedDurationMinutes.wrappedValue ?? 30
    }

    func clearEstimatedDuration() {
        estimatedDurationMinutes.wrappedValue = nil
    }

    var showsActualDurationControl: Bool {
        actualDurationMinutes != nil && taskType.wrappedValue == .todo
    }

    var hasActualDuration: Bool {
        actualDurationMinutes?.wrappedValue != nil
    }

    var actualDurationValue: Binding<Int> {
        let actualDurationMinutes = actualDurationMinutes
        return Binding(
            get: {
                max(
                    actualDurationMinutes?.wrappedValue ?? 30,
                    1
                )
            },
            set: {
                actualDurationMinutes?.wrappedValue =
                    RoutineTask.sanitizedActualDurationMinutes(max($0, 1))
            }
        )
    }

    func addActualDuration() {
        guard let actualDurationMinutes else { return }
        actualDurationMinutes.wrappedValue =
            actualDurationMinutes.wrappedValue ?? 30
    }

    func clearActualDuration() {
        actualDurationMinutes?.wrappedValue = nil
    }

    var hasStoryPoints: Bool {
        storyPoints.wrappedValue != nil
    }

    var storyPointsValue: Binding<Int> {
        let storyPoints = storyPoints
        return Binding(
            get: { max(storyPoints.wrappedValue ?? 1, 1) },
            set: { storyPoints.wrappedValue = RoutineTask.sanitizedStoryPoints(max($0, 1)) }
        )
    }

    func addStoryPoints() {
        storyPoints.wrappedValue = storyPoints.wrappedValue ?? 1
    }

    func clearStoryPoints() {
        storyPoints.wrappedValue = nil
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
}

enum TaskFormFlagSuggestionPresentation {
    static let collapsedLimit = 6

    static func visibleAvailableFlags(_ flags: [String], showsAll: Bool) -> [String] {
        showsAll ? flags : Array(flags.prefix(collapsedLimit))
    }
}

enum TaskFormTagFlagSectionPresentation {
    static func hasContent(
        routineTags: [String],
        tagDraft: String,
        routineFlags: [String],
        availableFlags: [String],
        flagDraft: String
    ) -> Bool {
        !routineTags.isEmpty
            || !tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !routineFlags.isEmpty
            || !availableFlags.isEmpty
            || !flagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
