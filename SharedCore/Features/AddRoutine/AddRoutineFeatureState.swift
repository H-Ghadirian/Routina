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
        basics: AddRoutineBasicsState = AddRoutineBasicsState(),
        organization: AddRoutineOrganizationState = AddRoutineOrganizationState(),
        schedule: AddRoutineScheduleState = AddRoutineScheduleState(),
        checklist: AddRoutineChecklistState = AddRoutineChecklistState()
    ) {
        self.basics = basics
        self.organization = organization
        self.schedule = schedule
        self.checklist = checklist
    }

    var taskType: RoutineTaskType {
        schedule.scheduleMode.taskType
    }

    var hasDeadline: Bool {
        basics.deadline != nil
    }

    var trimmedRoutineName: String {
        RoutineTask.trimmedName(basics.routineName) ?? ""
    }

    var candidateChecklistItems: [RoutineChecklistItem] {
        if let pendingItem = RoutineChecklistItem.normalizedTitle(checklist.checklistItemDraftTitle).map({
            RoutineChecklistItem(title: $0, intervalDays: checklist.checklistItemDraftInterval)
        }) {
            return checklist.routineChecklistItems + [pendingItem]
        }
        return checklist.routineChecklistItems
    }

    var isSaveDisabled: Bool {
        trimmedRoutineName.isEmpty
            || organization.nameValidationMessage != nil
            || (requiresChecklistItems && candidateChecklistItems.isEmpty)
    }

    var requiresChecklistItems: Bool {
        schedule.scheduleMode == .fixedIntervalChecklist || schedule.scheduleMode == .derivedFromChecklist
    }
}
