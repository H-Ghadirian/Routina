import ComposableArchitecture
import Foundation
import SwiftData

extension GoalsFeature {
    func loadGoalsEffect() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let goals = try context.fetch(
                    FetchDescriptor<RoutineGoal>(
                        sortBy: [
                            SortDescriptor(\.sortOrder),
                            SortDescriptor(\.title),
                        ]
                    )
                )
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                let tagColors = appSettingsClient.tagColors()
                let tagSummaries = RoutineTagColors.applying(
                    tagColors,
                    to: sortedTagSummaries(RoutineTag.summaries(from: tasks, goals: goals))
                )
                let tagCollections = tasks.map(\.tags) + goals.map(\.tags)
                let relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules() + RoutineTagRelations.learnedRules(from: tagCollections)
                )
                send(
                    .goalsLoaded(
                        GoalDisplay.displays(
                            goals: goals,
                            tasks: tasks,
                            referenceDate: now,
                            calendar: calendar
                        ),
                        tagSummaries,
                        relatedTagRules,
                        appSettingsClient.tagCounterDisplayMode(),
                        tagColors
                    ))
            } catch {
                send(.loadingFailed("Could not load goals."))
            }
        }
    }

    func saveGoalEffect(_ draft: GoalDraft) -> Effect<Action> {
        .run { @MainActor send in
            let context = modelContext()
            do {
                guard let title = draft.cleanedTitle,
                    let normalizedTitle = RoutineGoal.normalizedTitle(title)
                else {
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
                let parentGoalID = RoutineGoalHierarchy.sanitizedParentGoalID(
                    draft.parentGoalID,
                    for: draft.id,
                    in: allGoals,
                    id: { $0.id },
                    parentGoalID: { $0.parentGoalID }
                )
                if draft.parentGoalID != nil && parentGoalID == nil {
                    send(.loadingFailed("Choose a different parent goal."))
                    return
                }

                let savedGoalID: UUID
                if let id = draft.id,
                    let existingGoal = allGoals.first(where: { $0.id == id })
                {
                    existingGoal.title = title
                    existingGoal.emoji = RoutineGoal.cleanedEmoji(draft.emoji)
                    existingGoal.notes = RoutineGoal.cleanedNotes(draft.notes)
                    existingGoal.targetDate = draft.targetDate
                    existingGoal.tags = draft.tags
                    existingGoal.color = draft.color
                    existingGoal.parentGoalID = parentGoalID
                    savedGoalID = id
                } else {
                    let nextSortOrder = (allGoals.map(\.sortOrder).max() ?? -1) + 1
                    let goal = RoutineGoal(
                        title: title,
                        emoji: draft.emoji,
                        notes: draft.notes,
                        targetDate: draft.targetDate,
                        tags: draft.tags,
                        color: draft.color,
                        parentGoalID: parentGoalID,
                        createdAt: now,
                        sortOrder: nextSortOrder
                    )
                    savedGoalID = goal.id
                    context.insert(goal)
                }

                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.goalSaved(savedGoalID))
            } catch {
                context.rollback()
                send(.loadingFailed("Could not save goal."))
            }
        }
    }

    func setGoalStatusEffect(
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

    func deleteGoalEffect(goalID: UUID) -> Effect<Action> {
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
                let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
                for childGoal in goals where childGoal.parentGoalID == goalID {
                    childGoal.parentGoalID = nil
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

    func acceptTaskSuggestionsEffect(goalID: UUID, taskIDs: [UUID]) -> Effect<Action> {
        let taskIDs = RoutineGoalIDStorage.sanitized(taskIDs)
        guard !taskIDs.isEmpty else { return .none }

        return .run { @MainActor send in
            let context = modelContext()
            do {
                guard let goal = try context.fetch(goalDescriptor(for: goalID)).first else {
                    send(.refreshRequested)
                    return
                }

                let taskIDSet = Set(taskIDs)
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                for task in tasks where taskIDSet.contains(task.id) {
                    task.goalIDs = RoutineGoalIDStorage.sanitized(task.goalIDs + [goalID])
                }
                goal.rejectedTaskSuggestionIDs = goal.rejectedTaskSuggestionIDs.filter { !taskIDSet.contains($0) }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.refreshRequested)
            } catch {
                context.rollback()
                send(.loadingFailed("Could not link task to goal."))
            }
        }
    }

    func rejectTaskSuggestionsEffect(goalID: UUID, taskIDs: [UUID]) -> Effect<Action> {
        let taskIDs = RoutineGoalIDStorage.sanitized(taskIDs)
        guard !taskIDs.isEmpty else { return .none }

        return .run { @MainActor send in
            let context = modelContext()
            do {
                guard let goal = try context.fetch(goalDescriptor(for: goalID)).first else {
                    send(.refreshRequested)
                    return
                }

                goal.rejectedTaskSuggestionIDs = RoutineGoalIDStorage.sanitized(
                    goal.rejectedTaskSuggestionIDs + taskIDs
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
                send(.refreshRequested)
            } catch {
                context.rollback()
                send(.loadingFailed("Could not dismiss task suggestion."))
            }
        }
    }

    func goalDescriptor(for goalID: UUID) -> FetchDescriptor<RoutineGoal> {
        FetchDescriptor<RoutineGoal>(
            predicate: #Predicate { goal in
                goal.id == goalID
            }
        )
    }

    func sortedTagSummaries(_ summaries: [RoutineTagSummary]) -> [RoutineTagSummary] {
        summaries.sorted { lhs, rhs in
            let lhsTotal = lhs.linkedRoutineCount + lhs.linkedTodoCount + lhs.linkedGoalCount + lhs.doneCount
            let rhsTotal = rhs.linkedRoutineCount + rhs.linkedTodoCount + rhs.linkedGoalCount + rhs.doneCount

            if lhsTotal != rhsTotal {
                return lhsTotal > rhsTotal
            }
            if lhs.linkedGoalCount != rhs.linkedGoalCount {
                return lhs.linkedGoalCount > rhs.linkedGoalCount
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func persistAddGoalDraft(_ state: State) {
        guard state.editorDraft.id == nil else { return }
        GoalCreationDraftSnapshot(draft: state.editorDraft).persist(client: creationDraftClient)
    }
}
