import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct GoalsFeature {
    @ObservableState
    struct State: Equatable {
        var goals: [GoalDisplay] = []
        var searchText = ""
        var selectedGoalID: UUID?
        var isEditorPresented = false
        var editorDraft = GoalDraft()
        var validationMessage: String?
        var pendingDeleteGoalID: UUID?
        var isLoading = false

        var filteredGoals: [GoalDisplay] {
            Self.filtered(goals, by: searchText)
        }

        var activeGoals: [GoalDisplay] {
            filteredGoals.filter { $0.status == .active }
        }

        var archivedGoals: [GoalDisplay] {
            filteredGoals.filter { $0.status == .archived }
        }

        var selectedGoal: GoalDisplay? {
            guard let selectedGoalID else { return nil }
            return goals.first { $0.id == selectedGoalID }
        }

        static func filtered(_ goals: [GoalDisplay], by query: String) -> [GoalDisplay] {
            guard let normalizedQuery = RoutineGoal.normalizedTitle(query) else { return goals }
            return goals.filter { goal in
                goal.searchableText.contains(normalizedQuery)
            }
        }
    }

    struct GoalDisplay: Identifiable, Equatable, Hashable {
        var id: UUID
        var title: String
        var emoji: String?
        var notes: String?
        var targetDate: Date?
        var status: RoutineGoalStatus
        var color: RoutineTaskColor
        var createdAt: Date?
        var sortOrder: Int
        var linkedTasks: [GoalTaskDisplay]

        var displayEmoji: String {
            emoji.flatMap(RoutineGoal.cleanedEmoji) ?? "\u{1F3AF}"
        }

        var displayTitle: String {
            RoutineGoal.cleanedTitle(title) ?? "Untitled goal"
        }

        var routineCount: Int {
            linkedTasks.filter { !$0.isOneOffTask }.count
        }

        var todoCount: Int {
            linkedTasks.filter(\.isOneOffTask).count
        }

        var openTaskCount: Int {
            linkedTasks.filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }.count
        }

        var completedTodoCount: Int {
            linkedTasks.filter(\.isCompletedOneOff).count
        }

        var nextDueDate: Date? {
            linkedTasks.compactMap(\.dueDate).min()
        }

        var searchableText: String {
            ([displayTitle, notes ?? ""] + linkedTasks.map(\.displayName))
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }

        static func displays(
            goals: [RoutineGoal],
            tasks: [RoutineTask],
            referenceDate: Date,
            calendar: Calendar
        ) -> [GoalDisplay] {
            var tasksByGoalID: [UUID: [GoalTaskDisplay]] = [:]
            for task in tasks {
                let taskDisplay = GoalTaskDisplay(
                    task: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
                for goalID in task.goalIDs {
                    tasksByGoalID[goalID, default: []].append(taskDisplay)
                }
            }

            return goals
                .map { goal in
                    GoalDisplay(
                        id: goal.id,
                        title: goal.displayTitle,
                        emoji: goal.emoji,
                        notes: RoutineGoal.cleanedNotes(goal.notes),
                        targetDate: goal.targetDate,
                        status: goal.status,
                        color: goal.color,
                        createdAt: goal.createdAt,
                        sortOrder: goal.sortOrder,
                        linkedTasks: (tasksByGoalID[goal.id] ?? []).sorted()
                    )
                }
                .sorted()
        }
    }

    struct GoalTaskDisplay: Identifiable, Equatable, Hashable, Comparable {
        var id: UUID
        var name: String
        var emoji: String?
        var isOneOffTask: Bool
        var isCompletedOneOff: Bool
        var isCanceledOneOff: Bool
        var isPaused: Bool
        var isOngoing: Bool
        var dueDate: Date?

        var displayName: String {
            RoutineTask.trimmedName(name) ?? "Untitled task"
        }

        var displayEmoji: String {
            RoutineTask.sanitizedEmoji(emoji ?? "", fallback: isOneOffTask ? "\u{2705}" : "\u{1F501}")
        }

        var kindText: String {
            isOneOffTask ? "Todo" : "Routine"
        }

        var stateText: String {
            if isCompletedOneOff { return "Done" }
            if isCanceledOneOff { return "Canceled" }
            if isPaused { return "Paused" }
            if isOngoing { return "Ongoing" }
            return kindText
        }

        init(
            task: RoutineTask,
            referenceDate: Date,
            calendar: Calendar
        ) {
            self.id = task.id
            self.name = task.name ?? ""
            self.emoji = task.emoji
            self.isOneOffTask = task.isOneOffTask
            self.isCompletedOneOff = task.isCompletedOneOff
            self.isCanceledOneOff = task.isCanceledOneOff
            self.isPaused = task.isArchived(referenceDate: referenceDate, calendar: calendar)
            self.isOngoing = task.isOngoing
            if task.isOneOffTask {
                self.dueDate = task.deadline
            } else {
                self.dueDate = RoutineDateMath.dueDate(
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
        }

        static func < (lhs: GoalTaskDisplay, rhs: GoalTaskDisplay) -> Bool {
            switch (lhs.dueDate, rhs.dueDate) {
            case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
                return lhsDate < rhsDate
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }
    }

    struct GoalDraft: Equatable {
        var id: UUID?
        var title = ""
        var emoji = ""
        var notes = ""
        var targetDate: Date?
        var color: RoutineTaskColor = .none

        var hasTargetDate: Bool {
            targetDate != nil
        }

        var cleanedTitle: String? {
            RoutineGoal.cleanedTitle(title)
        }

        init(
            id: UUID? = nil,
            title: String = "",
            emoji: String = "",
            notes: String = "",
            targetDate: Date? = nil,
            color: RoutineTaskColor = .none
        ) {
            self.id = id
            self.title = title
            self.emoji = emoji
            self.notes = notes
            self.targetDate = targetDate
            self.color = color
        }

        init(goal: GoalDisplay) {
            self.init(
                id: goal.id,
                title: goal.displayTitle,
                emoji: goal.emoji ?? "",
                notes: goal.notes ?? "",
                targetDate: goal.targetDate,
                color: goal.color
            )
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case refreshRequested
        case goalsLoaded([GoalDisplay])
        case loadingFailed(String)
        case searchTextChanged(String)
        case selectGoal(UUID?)
        case addGoalTapped
        case editGoalTapped(UUID)
        case dismissEditor
        case editorTitleChanged(String)
        case editorEmojiChanged(String)
        case editorNotesChanged(String)
        case editorTargetDateEnabledChanged(Bool)
        case editorTargetDateChanged(Date)
        case editorColorChanged(RoutineTaskColor)
        case saveEditorTapped
        case goalSaved
        case archiveGoalTapped(UUID)
        case unarchiveGoalTapped(UUID)
        case deleteGoalRequested(UUID)
        case deleteGoalCanceled
        case deleteGoalConfirmed
    }

    @Dependency(\.modelContext) var modelContext
    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear, .refreshRequested:
                state.isLoading = true
                return loadGoalsEffect()

            case let .goalsLoaded(goals):
                state.goals = goals
                state.isLoading = false
                if let selectedGoalID = state.selectedGoalID,
                   goals.contains(where: { $0.id == selectedGoalID }) {
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
                return .none

            case let .selectGoal(goalID):
                state.selectedGoalID = goalID
                return .none

            case .addGoalTapped:
                state.editorDraft = GoalDraft()
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
                state.isEditorPresented = false
                state.validationMessage = nil
                return .none

            case let .editorTitleChanged(title):
                state.editorDraft.title = title
                state.validationMessage = nil
                return .none

            case let .editorEmojiChanged(emoji):
                state.editorDraft.emoji = String(emoji.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
                return .none

            case let .editorNotesChanged(notes):
                state.editorDraft.notes = notes
                return .none

            case let .editorTargetDateEnabledChanged(isEnabled):
                if isEnabled {
                    state.editorDraft.targetDate = state.editorDraft.targetDate
                        ?? calendar.date(byAdding: .month, value: 1, to: now)
                        ?? now
                } else {
                    state.editorDraft.targetDate = nil
                }
                return .none

            case let .editorTargetDateChanged(targetDate):
                state.editorDraft.targetDate = targetDate
                return .none

            case let .editorColorChanged(color):
                state.editorDraft.color = color
                return .none

            case .saveEditorTapped:
                guard state.editorDraft.cleanedTitle != nil else {
                    state.validationMessage = "Goal title is required."
                    return .none
                }
                return saveGoalEffect(state.editorDraft)

            case .goalSaved:
                state.isEditorPresented = false
                state.validationMessage = nil
                return loadGoalsEffect()

            case let .archiveGoalTapped(goalID):
                return setGoalStatusEffect(goalID: goalID, status: .archived)

            case let .unarchiveGoalTapped(goalID):
                return setGoalStatusEffect(goalID: goalID, status: .active)

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

    private func loadGoalsEffect() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let goals = try context.fetch(
                    FetchDescriptor<RoutineGoal>(
                        sortBy: [
                            SortDescriptor(\.sortOrder),
                            SortDescriptor(\.title)
                        ]
                    )
                )
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                send(.goalsLoaded(
                    GoalDisplay.displays(
                        goals: goals,
                        tasks: tasks,
                        referenceDate: now,
                        calendar: calendar
                    )
                ))
            } catch {
                send(.loadingFailed("Could not load goals."))
            }
        }
    }

    private func saveGoalEffect(_ draft: GoalDraft) -> Effect<Action> {
        .run { @MainActor send in
            let context = modelContext()
            do {
                guard let title = draft.cleanedTitle,
                      let normalizedTitle = RoutineGoal.normalizedTitle(title) else {
                    send(.loadingFailed("Goal title is required."))
                    return
                }
                let allGoals = try context.fetch(FetchDescriptor<RoutineGoal>())
                if allGoals.contains(where: { goal in
                    goal.id != draft.id && RoutineGoal.normalizedTitle(goal.title) == normalizedTitle
                }) {
                    send(.loadingFailed("A goal with this title already exists."))
                    return
                }

                if let id = draft.id,
                   let existingGoal = allGoals.first(where: { $0.id == id }) {
                    existingGoal.title = title
                    existingGoal.emoji = RoutineGoal.cleanedEmoji(draft.emoji)
                    existingGoal.notes = RoutineGoal.cleanedNotes(draft.notes)
                    existingGoal.targetDate = draft.targetDate
                    existingGoal.color = draft.color
                } else {
                    let nextSortOrder = (allGoals.map(\.sortOrder).max() ?? -1) + 1
                    context.insert(
                        RoutineGoal(
                            title: title,
                            emoji: draft.emoji,
                            notes: draft.notes,
                            targetDate: draft.targetDate,
                            color: draft.color,
                            createdAt: now,
                            sortOrder: nextSortOrder
                        )
                    )
                }

                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.goalSaved)
            } catch {
                context.rollback()
                send(.loadingFailed("Could not save goal."))
            }
        }
    }

    private func setGoalStatusEffect(
        goalID: UUID,
        status: RoutineGoalStatus
    ) -> Effect<Action> {
        .run { @MainActor send in
            let context = modelContext()
            do {
                guard let goal = try context.fetch(goalDescriptor(for: goalID)).first else { return }
                goal.status = status
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.refreshRequested)
            } catch {
                context.rollback()
                send(.loadingFailed("Could not update goal."))
            }
        }
    }

    private func deleteGoalEffect(goalID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            let context = modelContext()
            do {
                guard let goal = try context.fetch(goalDescriptor(for: goalID)).first else {
                    send(.refreshRequested)
                    return
                }
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                for task in tasks where task.goalIDs.contains(goalID) {
                    task.goalIDs = task.goalIDs.filter { $0 != goalID }
                }
                context.delete(goal)
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.refreshRequested)
            } catch {
                context.rollback()
                send(.loadingFailed("Could not delete goal."))
            }
        }
    }

    private func goalDescriptor(for goalID: UUID) -> FetchDescriptor<RoutineGoal> {
        FetchDescriptor<RoutineGoal>(
            predicate: #Predicate { goal in
                goal.id == goalID
            }
        )
    }
}

extension GoalsFeature.GoalDisplay: Comparable {
    static func < (lhs: GoalsFeature.GoalDisplay, rhs: GoalsFeature.GoalDisplay) -> Bool {
        if lhs.status != rhs.status {
            return lhs.status == .active
        }
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        switch (lhs.createdAt, rhs.createdAt) {
        case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }
}
