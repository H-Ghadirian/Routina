import Foundation
import ComposableArchitecture

struct AddRoutineFeature: Reducer {
    enum Frequency: String, CaseIterable, Equatable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var daysMultiplier: Int {
            switch self {
            case .day:
                return 1
            case .week:
                return 7
            case .month:
                return 30
            }
        }

        var singularLabel: String {
            switch self {
            case .day:
                return "day"
            case .week:
                return "week"
            case .month:
                return "month"
            }
        }
    }

    @ObservableState
    struct State: Equatable {
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
        var routineTags: [String] = []
        var relationships: [RoutineTaskRelationship] = []
        var availableTags: [String] = []
        var availableRelationshipTasks: [RoutineTaskRelationshipCandidate] = []
        var tagDraft: String = ""
        var scheduleMode: RoutineScheduleMode = .oneOff
        var routineSteps: [RoutineStep] = []
        var stepDraft: String = ""
        var routineChecklistItems: [RoutineChecklistItem] = []
        var checklistItemDraftTitle: String = ""
        var checklistItemDraftInterval: Int = 3
        var frequency: Frequency = .day
        var frequencyValue: Int = 1
        var recurrenceKind: RoutineRecurrenceRule.Kind = .intervalDays
        var recurrenceTimeOfDay: RoutineTimeOfDay = .defaultValue
        var recurrenceWeekday: Int = Calendar.current.component(.weekday, from: Date())
        var recurrenceDayOfMonth: Int = Calendar.current.component(.day, from: Date())
        var existingRoutineNames: [String] = []
        var availablePlaces: [RoutinePlaceSummary] = []
        var selectedPlaceID: UUID?
        var nameValidationMessage: String?

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

    enum Action: Equatable {
        case routineNameChanged(String)
        case routineEmojiChanged(String)
        case routineNotesChanged(String)
        case routineLinkChanged(String)
        case deadlineEnabledChanged(Bool)
        case deadlineDateChanged(Date)
        case priorityChanged(RoutineTaskPriority)
        case importanceChanged(RoutineTaskImportance)
        case urgencyChanged(RoutineTaskUrgency)
        case imagePicked(Data?)
        case removeImageTapped
        case attachmentPicked(Data, String)
        case removeAttachment(UUID)
        case taskTypeChanged(RoutineTaskType)
        case availableTagsChanged([String])
        case availableRelationshipTasksChanged([RoutineTaskRelationshipCandidate])
        case tagDraftChanged(String)
        case addTagTapped
        case removeTag(String)
        case toggleTagSelection(String)
        case addRelationship(UUID, RoutineTaskRelationshipKind)
        case removeRelationship(UUID)
        case tagRenamed(oldName: String, newName: String)
        case tagDeleted(String)
        case scheduleModeChanged(RoutineScheduleMode)
        case stepDraftChanged(String)
        case addStepTapped
        case removeStep(UUID)
        case moveStepUp(UUID)
        case moveStepDown(UUID)
        case checklistItemDraftTitleChanged(String)
        case checklistItemDraftIntervalChanged(Int)
        case addChecklistItemTapped
        case removeChecklistItem(UUID)
        case frequencyChanged(Frequency)
        case frequencyValueChanged(Int)
        case recurrenceKindChanged(RoutineRecurrenceRule.Kind)
        case recurrenceTimeOfDayChanged(RoutineTimeOfDay)
        case recurrenceWeekdayChanged(Int)
        case recurrenceDayOfMonthChanged(Int)
        case existingRoutineNamesChanged([String])
        case availablePlacesChanged([RoutinePlaceSummary])
        case selectedPlaceChanged(UUID?)
        case saveTapped
        case cancelTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didCancel
            case didSave(String, Int, RoutineRecurrenceRule, String, String?, String?, Date?, RoutineTaskPriority, RoutineTaskImportance, RoutineTaskUrgency, Data?, UUID?, [String], [RoutineTaskRelationship], [RoutineStep], RoutineScheduleMode, [RoutineChecklistItem], [AttachmentItem])
        }
    }

    @Dependency(\.date.now) var now

    var onSave: (String, Int, RoutineRecurrenceRule, String, String?, String?, Date?, RoutineTaskPriority, RoutineTaskImportance, RoutineTaskUrgency, Data?, UUID?, [String], [RoutineTaskRelationship], [RoutineStep], RoutineScheduleMode, [RoutineChecklistItem], [AttachmentItem]) -> Effect<Action>
    var onCancel: () -> Effect<Action>

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .routineNameChanged(name):
            state.routineName = name
            updateNameValidation(&state)
            return .none

        case let .routineEmojiChanged(emoji):
            state.routineEmoji = RoutineTask.sanitizedEmoji(emoji, fallback: state.routineEmoji)
            return .none

        case let .routineNotesChanged(notes):
            state.routineNotes = notes
            return .none

        case let .routineLinkChanged(link):
            state.routineLink = link
            return .none

        case let .deadlineEnabledChanged(isEnabled):
            state.deadline = isEnabled ? (state.deadline ?? now) : nil
            return .none

        case let .deadlineDateChanged(deadline):
            state.deadline = deadline
            return .none

        case let .priorityChanged(priority):
            state.priority = priority
            return .none

        case let .importanceChanged(importance):
            state.importance = importance
            state.priority = matrixPriority(
                importance: importance,
                urgency: state.urgency
            )
            return .none

        case let .urgencyChanged(urgency):
            state.urgency = urgency
            state.priority = matrixPriority(
                importance: state.importance,
                urgency: urgency
            )
            return .none

        case let .imagePicked(data):
            state.imageData = data.flatMap(TaskImageProcessor.compressedImageData(from:))
            return .none

        case .removeImageTapped:
            state.imageData = nil
            return .none

        case let .attachmentPicked(data, fileName):
            state.attachments.append(AttachmentItem(fileName: fileName, data: data))
            return .none

        case let .removeAttachment(id):
            state.attachments.removeAll { $0.id == id }
            return .none

        case let .taskTypeChanged(taskType):
            switch taskType {
            case .routine:
                if state.scheduleMode == .oneOff {
                    state.scheduleMode = .fixedInterval
                }
                state.deadline = nil
            case .todo:
                state.scheduleMode = .oneOff
            }
            return .none

        case let .availableTagsChanged(tags):
            state.availableTags = RoutineTag.allTags(from: [tags])
            return .none

        case let .availableRelationshipTasksChanged(tasks):
            state.availableRelationshipTasks = tasks
            state.relationships = RoutineTaskRelationship.sanitized(
                state.relationships.filter { relationship in
                    tasks.contains(where: { $0.id == relationship.targetTaskID })
                }
            )
            return .none

        case let .tagDraftChanged(value):
            state.tagDraft = value
            return .none

        case .addTagTapped:
            state.routineTags = RoutineTag.appending(state.tagDraft, to: state.routineTags)
            state.tagDraft = ""
            return .none

        case let .removeTag(tag):
            state.routineTags = RoutineTag.removing(tag, from: state.routineTags)
            return .none

        case let .toggleTagSelection(tag):
            if RoutineTag.contains(tag, in: state.routineTags) {
                state.routineTags = RoutineTag.removing(tag, from: state.routineTags)
            } else {
                state.routineTags = RoutineTag.appending(tag, to: state.routineTags)
            }
            return .none

        case let .addRelationship(taskID, kind):
            state.relationships = RoutineTaskRelationship.sanitized(
                state.relationships + [RoutineTaskRelationship(targetTaskID: taskID, kind: kind)]
            )
            return .none

        case let .removeRelationship(taskID):
            state.relationships.removeAll { $0.targetTaskID == taskID }
            return .none

        case let .tagRenamed(oldName, newName):
            state.availableTags = RoutineTag.replacing(oldName, with: newName, in: state.availableTags)
            if RoutineTag.contains(oldName, in: state.routineTags) {
                state.routineTags = RoutineTag.replacing(oldName, with: newName, in: state.routineTags)
            }
            return .none

        case let .tagDeleted(tag):
            state.availableTags = RoutineTag.removing(tag, from: state.availableTags)
            state.routineTags = RoutineTag.removing(tag, from: state.routineTags)
            return .none

        case let .scheduleModeChanged(mode):
            state.scheduleMode = mode
            return .none

        case let .stepDraftChanged(value):
            state.stepDraft = value
            return .none

        case .addStepTapped:
            state.routineSteps = appendStep(from: state.stepDraft, to: state.routineSteps)
            state.stepDraft = ""
            return .none

        case let .removeStep(stepID):
            state.routineSteps.removeAll { $0.id == stepID }
            return .none

        case let .moveStepUp(stepID):
            moveStep(stepID, by: -1, state: &state)
            return .none

        case let .moveStepDown(stepID):
            moveStep(stepID, by: 1, state: &state)
            return .none

        case let .checklistItemDraftTitleChanged(value):
            state.checklistItemDraftTitle = value
            return .none

        case let .checklistItemDraftIntervalChanged(value):
            state.checklistItemDraftInterval = RoutineChecklistItem.clampedIntervalDays(value)
            return .none

        case .addChecklistItemTapped:
            state.routineChecklistItems = appendChecklistItem(
                from: state.checklistItemDraftTitle,
                intervalDays: state.checklistItemDraftInterval,
                createdAt: now,
                to: state.routineChecklistItems
            )
            state.checklistItemDraftTitle = ""
            state.checklistItemDraftInterval = 3
            return .none

        case let .removeChecklistItem(itemID):
            state.routineChecklistItems.removeAll { $0.id == itemID }
            return .none

        case let .frequencyChanged(freq):
            state.frequency = freq
            return .none

        case let .frequencyValueChanged(value):
            state.frequencyValue = value
            return .none

        case let .recurrenceKindChanged(kind):
            state.recurrenceKind = kind
            return .none

        case let .recurrenceTimeOfDayChanged(timeOfDay):
            state.recurrenceTimeOfDay = timeOfDay
            return .none

        case let .recurrenceWeekdayChanged(weekday):
            state.recurrenceWeekday = min(max(weekday, 1), 7)
            return .none

        case let .recurrenceDayOfMonthChanged(dayOfMonth):
            state.recurrenceDayOfMonth = min(max(dayOfMonth, 1), 31)
            return .none

        case let .existingRoutineNamesChanged(names):
            state.existingRoutineNames = names
            updateNameValidation(&state)
            return .none

        case let .availablePlacesChanged(places):
            state.availablePlaces = places
            if let selectedPlaceID = state.selectedPlaceID,
               !places.contains(where: { $0.id == selectedPlaceID }) {
                state.selectedPlaceID = nil
            }
            return .none

        case let .selectedPlaceChanged(placeID):
            state.selectedPlaceID = placeID
            return .none

        case .saveTapped:
            state.routineTags = RoutineTag.appending(state.tagDraft, to: state.routineTags)
            state.tagDraft = ""
            state.routineSteps = appendStep(from: state.stepDraft, to: state.routineSteps)
            state.stepDraft = ""
            state.routineChecklistItems = appendChecklistItem(
                from: state.checklistItemDraftTitle,
                intervalDays: state.checklistItemDraftInterval,
                createdAt: now,
                to: state.routineChecklistItems
            )
            state.checklistItemDraftTitle = ""
            state.checklistItemDraftInterval = 3
            updateNameValidation(&state)
            guard !state.isSaveDisabled else { return .none }
            let frequencyInDays = state.scheduleMode == .oneOff
                ? 1
                : state.frequencyValue * state.frequency.daysMultiplier
            let recurrenceRule = selectedRecurrenceRule(
                for: state,
                fallbackInterval: frequencyInDays
            )
            return onSave(
                state.trimmedRoutineName,
                frequencyInDays,
                recurrenceRule,
                state.routineEmoji,
                RoutineTask.sanitizedNotes(state.routineNotes),
                RoutineTask.sanitizedLink(state.routineLink),
                state.taskType == .todo ? state.deadline : nil,
                matrixPriority(
                    importance: state.importance,
                    urgency: state.urgency
                ),
                state.importance,
                state.urgency,
                state.imageData,
                state.selectedPlaceID,
                state.routineTags,
                state.relationships,
                (state.scheduleMode == .fixedInterval || state.scheduleMode == .oneOff)
                    ? RoutineStep.sanitized(state.routineSteps)
                    : [],
                state.scheduleMode,
                (state.scheduleMode == .fixedInterval || state.scheduleMode == .oneOff)
                    ? []
                    : RoutineChecklistItem.sanitized(state.routineChecklistItems),
                state.attachments
            )

        case .cancelTapped:
            return onCancel()
        case .delegate(_):
            return .none
        }
    }

    private func updateNameValidation(_ state: inout State) {
        guard let normalizedName = RoutineTask.normalizedName(state.routineName) else {
            state.nameValidationMessage = nil
            return
        }

        let hasDuplicate = state.existingRoutineNames.contains { existingName in
            RoutineTask.normalizedName(existingName) == normalizedName
        }

        state.nameValidationMessage = hasDuplicate
            ? "A task with this name already exists."
            : nil
    }

    private func matrixPriority(
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency
    ) -> RoutineTaskPriority {
        let score = importance.sortOrder + urgency.sortOrder
        switch score {
        case ..<4:
            return .low
        case 4...5:
            return .medium
        case 6...7:
            return .high
        default:
            return .urgent
        }
    }

    private func appendStep(from draft: String, to currentSteps: [RoutineStep]) -> [RoutineStep] {
        guard let title = RoutineStep.normalizedTitle(draft) else { return currentSteps }
        return currentSteps + [RoutineStep(title: title)]
    }

    private func appendChecklistItem(
        from draftTitle: String,
        intervalDays: Int,
        createdAt: Date,
        to currentItems: [RoutineChecklistItem]
    ) -> [RoutineChecklistItem] {
        guard let title = RoutineChecklistItem.normalizedTitle(draftTitle) else { return currentItems }
        return currentItems + [
            RoutineChecklistItem(
                title: title,
                intervalDays: intervalDays,
                createdAt: createdAt
            )
        ]
    }

    private func moveStep(_ stepID: UUID, by offset: Int, state: inout State) {
        guard let index = state.routineSteps.firstIndex(where: { $0.id == stepID }) else { return }
        let targetIndex = index + offset
        guard state.routineSteps.indices.contains(targetIndex) else { return }
        let step = state.routineSteps.remove(at: index)
        state.routineSteps.insert(step, at: targetIndex)
    }

    private func selectedRecurrenceRule(
        for state: State,
        fallbackInterval: Int
    ) -> RoutineRecurrenceRule {
        guard state.scheduleMode != .oneOff else {
            return .interval(days: 1)
        }

        guard state.scheduleMode != .derivedFromChecklist else {
            return .interval(days: max(fallbackInterval, 1))
        }

        switch state.recurrenceKind {
        case .intervalDays:
            return .interval(days: max(fallbackInterval, 1))
        case .dailyTime:
            return .daily(at: state.recurrenceTimeOfDay)
        case .weekly:
            return .weekly(on: state.recurrenceWeekday)
        case .monthlyDay:
            return .monthly(on: state.recurrenceDayOfMonth)
        }
    }
}
