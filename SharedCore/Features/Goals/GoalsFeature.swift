import ComposableArchitecture
import Foundation

@Reducer
struct GoalsFeature {
    @ObservableState
    struct State: Equatable {
        var goals: [GoalDisplay] = []
        var availableTags: [String] = []
        var availableTagSummaries: [RoutineTagSummary] = []
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var tagCounterDisplayMode: TagCounterDisplayMode = .defaultValue
        var tagColors: [String: String] = [:]
        var searchText = ""
        var selectedGoalID: UUID?
        var deepLinkedGoalNavigationID: UUID?
        var isEditorPresented = false
        var editorDraft = GoalDraft()
        var validationMessage: String?
        var pendingDeleteGoalID: UUID?
        var isLoading = false
        var filteredGoalSnapshot: [GoalDisplay] = []
        var activeGoalSnapshot: [GoalDisplay] = []
        var archivedGoalSnapshot: [GoalDisplay] = []
        var goalDisplaysByID: [UUID: GoalDisplay] = [:]
        var hasBuiltGoalPresentation = false

        var filteredGoals: [GoalDisplay] {
            hasBuiltGoalPresentation ? filteredGoalSnapshot : Self.filtered(goals, by: searchText)
        }

        var activeGoals: [GoalDisplay] {
            hasBuiltGoalPresentation
                ? activeGoalSnapshot
                : filteredGoals.filter { $0.status == .active }
        }

        var archivedGoals: [GoalDisplay] {
            hasBuiltGoalPresentation
                ? archivedGoalSnapshot
                : filteredGoals.filter { $0.status == .archived }
        }

        var selectedGoal: GoalDisplay? {
            guard let selectedGoalID else { return nil }
            return goalDisplaysByID[selectedGoalID] ?? goals.first { $0.id == selectedGoalID }
        }

        var isAddingGoal: Bool {
            isEditorPresented && editorDraft.id == nil
        }

        var availableParentGoals: [GoalLinkDisplay] {
            let excludedGoalIDs: Set<UUID>
            if let editingGoalID = editorDraft.id {
                excludedGoalIDs = RoutineGoalHierarchy.descendantIDs(
                    of: editingGoalID,
                    in: goals,
                    id: { $0.id },
                    parentGoalID: { $0.parentGoalID }
                ).union([editingGoalID])
            } else {
                excludedGoalIDs = []
            }

            return
                goals
                .filter { !excludedGoalIDs.contains($0.id) }
                .map(GoalLinkDisplay.init(goal:))
                .sorted()
        }

        static func filtered(_ goals: [GoalDisplay], by query: String) -> [GoalDisplay] {
            guard let normalizedQuery = RoutineGoal.normalizedTitle(query) else { return goals }
            return goals.filter { goal in
                goal.searchableText.contains(normalizedQuery)
            }
        }

        mutating func refreshGoalPresentation() {
            let filteredGoals = Self.filtered(goals, by: searchText)
            filteredGoalSnapshot = filteredGoals
            activeGoalSnapshot = filteredGoals.filter { $0.status == .active }
            archivedGoalSnapshot = filteredGoals.filter { $0.status == .archived }
            goalDisplaysByID = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
            hasBuiltGoalPresentation = true
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case refreshRequested
        case goalsLoaded(
            [GoalDisplay],
            [RoutineTagSummary],
            [RoutineRelatedTagRule],
            TagCounterDisplayMode,
            [String: String]
        )
        case loadingFailed(String)
        case searchTextChanged(String)
        case selectGoal(UUID?)
        case openGoalDeepLink(UUID)
        case goalDeepLinkNavigationHandled(UUID)
        case addGoalTapped
        case editGoalTapped(UUID)
        case dismissEditor
        case editorTitleChanged(String)
        case editorEmojiChanged(String)
        case editorNotesChanged(String)
        case editorTargetDateEnabledChanged(Bool)
        case editorTargetDateChanged(Date)
        case editorTagDraftChanged(String)
        case editorAcceptTagAutocompleteTapped
        case editorAddTagTapped
        case editorRemoveTagTapped(String)
        case editorToggleTagSelection(String)
        case editorColorChanged(RoutineTaskColor)
        case editorParentGoalChanged(UUID?)
        case saveEditorTapped
        case goalSaved(UUID)
        case archiveGoalTapped(UUID)
        case unarchiveGoalTapped(UUID)
        case acceptTaskSuggestion(goalID: UUID, taskID: UUID)
        case rejectTaskSuggestion(goalID: UUID, taskID: UUID)
        case acceptAllTaskSuggestions(goalID: UUID, taskIDs: [UUID])
        case rejectAllTaskSuggestions(goalID: UUID, taskIDs: [UUID])
        case deleteGoalRequested(UUID)
        case deleteGoalCanceled
        case deleteGoalConfirmed
    }

    @Dependency(\.modelContext) var modelContext
    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.creationDraftClient) var creationDraftClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear, .refreshRequested:
                state.isLoading = true
                return loadGoalsEffect()

            case let .goalsLoaded(goals, tagSummaries, relatedTagRules, tagCounterDisplayMode, tagColors):
                state.goals = goals
                state.refreshGoalPresentation()
                state.availableTagSummaries = tagSummaries
                state.availableTags = tagSummaries.map(\.name)
                state.editorDraft.tags = RoutineTag.deduplicated(
                    state.editorDraft.tags,
                    preferredTags: state.availableTags
                )
                state.relatedTagRules = relatedTagRules
                state.tagCounterDisplayMode = tagCounterDisplayMode
                state.tagColors = tagColors
                state.isLoading = false
                if let deepLinkedGoalID = state.deepLinkedGoalNavigationID {
                    if goals.contains(where: { $0.id == deepLinkedGoalID }) {
                        state.selectedGoalID = deepLinkedGoalID
                    } else {
                        state.deepLinkedGoalNavigationID = nil
                    }
                    return .none
                }
                if let selectedGoalID = state.selectedGoalID,
                    goals.contains(where: { $0.id == selectedGoalID })
                {
                    return .none
                }
                state.selectedGoalID = goals.first(where: { $0.status == .active })?.id ?? goals.first?.id
                return .none

            case let .loadingFailed(message):
                state.isLoading = false
                state.validationMessage = message
                return .none

            case let .searchTextChanged(searchText):
                state.searchText = searchText
                state.refreshGoalPresentation()
                return .none

            case let .selectGoal(goalID):
                state.selectedGoalID = goalID
                return .none

            case let .openGoalDeepLink(goalID):
                state.searchText = ""
                state.refreshGoalPresentation()
                state.isEditorPresented = false
                state.selectedGoalID = goalID
                state.deepLinkedGoalNavigationID = goalID
                guard state.goals.contains(where: { $0.id == goalID }) else {
                    return loadGoalsEffect()
                }
                return .none

            case let .goalDeepLinkNavigationHandled(goalID):
                if state.deepLinkedGoalNavigationID == goalID {
                    state.deepLinkedGoalNavigationID = nil
                }
                return .none

            case .addGoalTapped:
                state.editorDraft = GoalCreationDraftSnapshot.load(client: creationDraftClient)?.draft ?? GoalDraft()
                state.validationMessage = nil
                state.isEditorPresented = true
                return .none

            case let .editGoalTapped(goalID):
                guard let goal = state.goals.first(where: { $0.id == goalID }) else { return .none }
                state.editorDraft = GoalDraft(goal: goal)
                state.validationMessage = nil
                state.isEditorPresented = true
                return .none

            case .dismissEditor:
                if state.isAddingGoal {
                    creationDraftClient.clear(.goal)
                }
                state.isEditorPresented = false
                state.validationMessage = nil
                return .none

            case let .editorTitleChanged(title):
                state.editorDraft.title = title
                state.validationMessage = nil
                persistAddGoalDraft(state)
                return .none

            case let .editorEmojiChanged(emoji):
                state.editorDraft.emoji = String(emoji.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
                persistAddGoalDraft(state)
                return .none

            case let .editorNotesChanged(notes):
                state.editorDraft.notes = notes
                persistAddGoalDraft(state)
                return .none

            case let .editorTargetDateEnabledChanged(isEnabled):
                if isEnabled {
                    state.editorDraft.targetDate =
                        state.editorDraft.targetDate
                        ?? calendar.date(byAdding: .month, value: 1, to: now)
                        ?? now
                } else {
                    state.editorDraft.targetDate = nil
                }
                persistAddGoalDraft(state)
                return .none

            case let .editorTargetDateChanged(targetDate):
                state.editorDraft.targetDate = targetDate
                persistAddGoalDraft(state)
                return .none

            case let .editorTagDraftChanged(tagDraft):
                state.editorDraft.tagDraft = tagDraft
                persistAddGoalDraft(state)
                return .none

            case .editorAcceptTagAutocompleteTapped:
                guard
                    let suggestion = RoutineTag.autocompleteSuggestion(
                        for: state.editorDraft.tagDraft,
                        availableTags: state.availableTags,
                        selectedTags: state.editorDraft.tags
                    )
                else {
                    return .none
                }
                state.editorDraft.tagDraft = RoutineTag.acceptingAutocompleteSuggestion(
                    suggestion,
                    in: state.editorDraft.tagDraft
                )
                persistAddGoalDraft(state)
                return .none

            case .editorAddTagTapped:
                let updatedTags = RoutineTag.appending(
                    state.editorDraft.tagDraft,
                    to: state.editorDraft.tags,
                    availableTags: state.availableTags
                )
                guard updatedTags != state.editorDraft.tags else { return .none }
                state.editorDraft.tags = updatedTags
                state.editorDraft.tagDraft = ""
                persistAddGoalDraft(state)
                return .none

            case let .editorRemoveTagTapped(tag):
                state.editorDraft.tags = RoutineTag.removing(tag, from: state.editorDraft.tags)
                persistAddGoalDraft(state)
                return .none

            case let .editorToggleTagSelection(tag):
                if RoutineTag.contains(tag, in: state.editorDraft.tags) {
                    state.editorDraft.tags = RoutineTag.removing(tag, from: state.editorDraft.tags)
                } else {
                    state.editorDraft.tags = RoutineTag.appending(
                        tag,
                        to: state.editorDraft.tags,
                        availableTags: state.availableTags
                    )
                }
                persistAddGoalDraft(state)
                return .none

            case let .editorColorChanged(color):
                state.editorDraft.color = color
                persistAddGoalDraft(state)
                return .none

            case let .editorParentGoalChanged(parentGoalID):
                state.editorDraft.parentGoalID = parentGoalID
                persistAddGoalDraft(state)
                return .none

            case .saveEditorTapped:
                guard state.editorDraft.cleanedTitle != nil else {
                    state.validationMessage = "Goal title is required."
                    return .none
                }
                return saveGoalEffect(state.editorDraft)

            case let .goalSaved(goalID):
                if state.editorDraft.id == nil {
                    creationDraftClient.clear(.goal)
                }
                state.isEditorPresented = false
                state.validationMessage = nil
                state.searchText = ""
                if state.hasBuiltGoalPresentation {
                    state.refreshGoalPresentation()
                }
                state.selectedGoalID = goalID
                return loadGoalsEffect()

            case let .archiveGoalTapped(goalID):
                return setGoalStatusEffect(goalID: goalID, status: .archived)

            case let .unarchiveGoalTapped(goalID):
                return setGoalStatusEffect(goalID: goalID, status: .active)

            case let .acceptTaskSuggestion(goalID, taskID):
                return acceptTaskSuggestionsEffect(goalID: goalID, taskIDs: [taskID])

            case let .rejectTaskSuggestion(goalID, taskID):
                return rejectTaskSuggestionsEffect(goalID: goalID, taskIDs: [taskID])

            case let .acceptAllTaskSuggestions(goalID, taskIDs):
                return acceptTaskSuggestionsEffect(goalID: goalID, taskIDs: taskIDs)

            case let .rejectAllTaskSuggestions(goalID, taskIDs):
                return rejectTaskSuggestionsEffect(goalID: goalID, taskIDs: taskIDs)

            case let .deleteGoalRequested(goalID):
                state.pendingDeleteGoalID = goalID
                return .none

            case .deleteGoalCanceled:
                state.pendingDeleteGoalID = nil
                return .none

            case .deleteGoalConfirmed:
                guard let goalID = state.pendingDeleteGoalID else { return .none }
                state.pendingDeleteGoalID = nil
                return deleteGoalEffect(goalID: goalID)
            }
        }
    }
}
