import ComposableArchitecture
import Foundation

struct AddRoutineBasicsState: Equatable {
    var routineName: String = ""
    var routineEmoji: String = "✨"
    var routineNotes: String = ""
    var routineLink: String = ""
    var deadline: Date?
    var priority: RoutineTaskPriority = .medium
    var importance: RoutineTaskImportance = .level2
    var urgency: RoutineTaskUrgency = .level2
    var imageData: Data?
    var attachments: [AttachmentItem] = []
    var selectedPlaceID: UUID?
    var routineColor: RoutineTaskColor = .none
}

struct AddRoutineOrganizationState: Equatable {
    var routineTags: [String] = []
    var relationships: [RoutineTaskRelationship] = []
    var availableTags: [String] = []
    var availableTagSummaries: [RoutineTagSummary] = []
    var tagCounterDisplayMode: TagCounterDisplayMode = .defaultValue
    var availableRelationshipTasks: [RoutineTaskRelationshipCandidate] = []
    var tagDraft: String = ""
    var existingRoutineNames: [String] = []
    var availablePlaces: [RoutinePlaceSummary] = []
    var nameValidationMessage: String?
}

struct AddRoutineScheduleState: Equatable {
    var scheduleMode: RoutineScheduleMode = .oneOff
    var frequency: AddRoutineFeature.Frequency = .day
    var frequencyValue: Int = 1
    var recurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays
    var recurrenceTimeOfDay: RoutineTimeOfDay = .defaultValue
    var recurrenceWeekday: Int = Calendar.current.component(.weekday, from: Date())
    var recurrenceDayOfMonth: Int = Calendar.current.component(.day, from: Date())
}

struct AddRoutineChecklistState: Equatable {
    var routineSteps: [RoutineStep] = []
    var stepDraft: String = ""
    var routineChecklistItems: [RoutineChecklistItem] = []
    var checklistItemDraftTitle: String = ""
    var checklistItemDraftInterval: Int = 3
}

@ObservableState
struct AddRoutineFeatureState: Equatable {
    var basics = AddRoutineBasicsState()
    var organization = AddRoutineOrganizationState()
    var schedule = AddRoutineScheduleState()
    var checklist = AddRoutineChecklistState()

    init(
        routineName: String = "",
        routineEmoji: String = "✨",
        routineNotes: String = "",
        routineLink: String = "",
        deadline: Date? = nil,
        priority: RoutineTaskPriority = .medium,
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        imageData: Data? = nil,
        attachments: [AttachmentItem] = [],
        routineTags: [String] = [],
        relationships: [RoutineTaskRelationship] = [],
        availableTags: [String] = [],
        availableTagSummaries: [RoutineTagSummary] = [],
        tagCounterDisplayMode: TagCounterDisplayMode = .defaultValue,
        availableRelationshipTasks: [RoutineTaskRelationshipCandidate] = [],
        tagDraft: String = "",
        scheduleMode: RoutineScheduleMode = .oneOff,
        routineSteps: [RoutineStep] = [],
        stepDraft: String = "",
        routineChecklistItems: [RoutineChecklistItem] = [],
        checklistItemDraftTitle: String = "",
        checklistItemDraftInterval: Int = 3,
        frequency: AddRoutineFeature.Frequency = .day,
        frequencyValue: Int = 1,
        recurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays,
        recurrenceTimeOfDay: RoutineTimeOfDay = .defaultValue,
        recurrenceWeekday: Int = Calendar.current.component(.weekday, from: Date()),
        recurrenceDayOfMonth: Int = Calendar.current.component(.day, from: Date()),
        existingRoutineNames: [String] = [],
        availablePlaces: [RoutinePlaceSummary] = [],
        selectedPlaceID: UUID? = nil,
        nameValidationMessage: String? = nil,
        routineColor: RoutineTaskColor = .none
    ) {
        self.basics = AddRoutineBasicsState(
            routineName: routineName,
            routineEmoji: routineEmoji,
            routineNotes: routineNotes,
            routineLink: routineLink,
            deadline: deadline,
            priority: priority,
            importance: importance,
            urgency: urgency,
            imageData: imageData,
            attachments: attachments,
            selectedPlaceID: selectedPlaceID,
            routineColor: routineColor
        )
        self.organization = AddRoutineOrganizationState(
            routineTags: routineTags,
            relationships: relationships,
            availableTags: availableTags,
            availableTagSummaries: availableTagSummaries,
            tagCounterDisplayMode: tagCounterDisplayMode,
            availableRelationshipTasks: availableRelationshipTasks,
            tagDraft: tagDraft,
            existingRoutineNames: existingRoutineNames,
            availablePlaces: availablePlaces,
            nameValidationMessage: nameValidationMessage
        )
        self.schedule = AddRoutineScheduleState(
            scheduleMode: scheduleMode,
            frequency: frequency,
            frequencyValue: frequencyValue,
            recurrenceKind: recurrenceKind,
            recurrenceTimeOfDay: recurrenceTimeOfDay,
            recurrenceWeekday: recurrenceWeekday,
            recurrenceDayOfMonth: recurrenceDayOfMonth
        )
        self.checklist = AddRoutineChecklistState(
            routineSteps: routineSteps,
            stepDraft: stepDraft,
            routineChecklistItems: routineChecklistItems,
            checklistItemDraftTitle: checklistItemDraftTitle,
            checklistItemDraftInterval: checklistItemDraftInterval
        )
    }

    var routineName: String {
        get { basics.routineName }
        set { basics.routineName = newValue }
    }

    var routineEmoji: String {
        get { basics.routineEmoji }
        set { basics.routineEmoji = newValue }
    }

    var routineNotes: String {
        get { basics.routineNotes }
        set { basics.routineNotes = newValue }
    }

    var routineLink: String {
        get { basics.routineLink }
        set { basics.routineLink = newValue }
    }

    var deadline: Date? {
        get { basics.deadline }
        set { basics.deadline = newValue }
    }

    var priority: RoutineTaskPriority {
        get { basics.priority }
        set { basics.priority = newValue }
    }

    var importance: RoutineTaskImportance {
        get { basics.importance }
        set { basics.importance = newValue }
    }

    var urgency: RoutineTaskUrgency {
        get { basics.urgency }
        set { basics.urgency = newValue }
    }

    var imageData: Data? {
        get { basics.imageData }
        set { basics.imageData = newValue }
    }

    var attachments: [AttachmentItem] {
        get { basics.attachments }
        set { basics.attachments = newValue }
    }

    var selectedPlaceID: UUID? {
        get { basics.selectedPlaceID }
        set { basics.selectedPlaceID = newValue }
    }

    var routineColor: RoutineTaskColor {
        get { basics.routineColor }
        set { basics.routineColor = newValue }
    }

    var routineTags: [String] {
        get { organization.routineTags }
        set { organization.routineTags = newValue }
    }

    var relationships: [RoutineTaskRelationship] {
        get { organization.relationships }
        set { organization.relationships = newValue }
    }

    var availableTags: [String] {
        get { organization.availableTags }
        set { organization.availableTags = newValue }
    }

    var availableTagSummaries: [RoutineTagSummary] {
        get { organization.availableTagSummaries }
        set { organization.availableTagSummaries = newValue }
    }

    var tagCounterDisplayMode: TagCounterDisplayMode {
        get { organization.tagCounterDisplayMode }
        set { organization.tagCounterDisplayMode = newValue }
    }

    var availableRelationshipTasks: [RoutineTaskRelationshipCandidate] {
        get { organization.availableRelationshipTasks }
        set { organization.availableRelationshipTasks = newValue }
    }

    var tagDraft: String {
        get { organization.tagDraft }
        set { organization.tagDraft = newValue }
    }

    var existingRoutineNames: [String] {
        get { organization.existingRoutineNames }
        set { organization.existingRoutineNames = newValue }
    }

    var availablePlaces: [RoutinePlaceSummary] {
        get { organization.availablePlaces }
        set { organization.availablePlaces = newValue }
    }

    var nameValidationMessage: String? {
        get { organization.nameValidationMessage }
        set { organization.nameValidationMessage = newValue }
    }

    var scheduleMode: RoutineScheduleMode {
        get { schedule.scheduleMode }
        set { schedule.scheduleMode = newValue }
    }

    var frequency: AddRoutineFeature.Frequency {
        get { schedule.frequency }
        set { schedule.frequency = newValue }
    }

    var frequencyValue: Int {
        get { schedule.frequencyValue }
        set { schedule.frequencyValue = newValue }
    }

    var recurrenceKind: RoutineRecurrenceRule.Kind {
        get { schedule.recurrenceKind }
        set { schedule.recurrenceKind = newValue }
    }

    var recurrenceTimeOfDay: RoutineTimeOfDay {
        get { schedule.recurrenceTimeOfDay }
        set { schedule.recurrenceTimeOfDay = newValue }
    }

    var recurrenceWeekday: Int {
        get { schedule.recurrenceWeekday }
        set { schedule.recurrenceWeekday = newValue }
    }

    var recurrenceDayOfMonth: Int {
        get { schedule.recurrenceDayOfMonth }
        set { schedule.recurrenceDayOfMonth = newValue }
    }

    var routineSteps: [RoutineStep] {
        get { checklist.routineSteps }
        set { checklist.routineSteps = newValue }
    }

    var stepDraft: String {
        get { checklist.stepDraft }
        set { checklist.stepDraft = newValue }
    }

    var routineChecklistItems: [RoutineChecklistItem] {
        get { checklist.routineChecklistItems }
        set { checklist.routineChecklistItems = newValue }
    }

    var checklistItemDraftTitle: String {
        get { checklist.checklistItemDraftTitle }
        set { checklist.checklistItemDraftTitle = newValue }
    }

    var checklistItemDraftInterval: Int {
        get { checklist.checklistItemDraftInterval }
        set { checklist.checklistItemDraftInterval = newValue }
    }

    var taskType: RoutineTaskType {
        scheduleMode.taskType
    }

    var hasDeadline: Bool {
        deadline != nil
    }

    var trimmedRoutineName: String {
        RoutineTask.trimmedName(routineName) ?? ""
    }

    var candidateChecklistItems: [RoutineChecklistItem] {
        if let pendingItem = RoutineChecklistItem.normalizedTitle(checklistItemDraftTitle).map({
            RoutineChecklistItem(title: $0, intervalDays: checklistItemDraftInterval)
        }) {
            return routineChecklistItems + [pendingItem]
        }
        return routineChecklistItems
    }

    var isSaveDisabled: Bool {
        trimmedRoutineName.isEmpty
            || nameValidationMessage != nil
            || (requiresChecklistItems && candidateChecklistItems.isEmpty)
    }

    var requiresChecklistItems: Bool {
        scheduleMode == .fixedIntervalChecklist || scheduleMode == .derivedFromChecklist
    }
}
