import ComposableArchitecture
import Foundation
import SwiftData

extension TaskDetailFeature {
    func matrixPriority(
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency
    ) -> RoutineTaskPriority {
        let score = importance.sortOrder + urgency.sortOrder
        switch score {
        case ..<4:
            return .low
        case 4:
            return .medium
        case 5...6:
            return .high
        default:
            return .urgent
        }
    }

    func selectedRecurrenceRule(
        for state: State,
        fallbackInterval: Int
    ) -> RoutineRecurrenceRule {
        guard state.editScheduleMode != .oneOff else {
            return .interval(days: 1)
        }

        guard state.editScheduleMode != .softInterval else {
            return .interval(days: max(fallbackInterval, 1))
        }

        guard state.editScheduleMode != .derivedFromChecklist else {
            return .interval(days: max(fallbackInterval, 1))
        }

        switch state.editRecurrenceKind {
        case .intervalDays:
            return .interval(days: max(fallbackInterval, 1))
        case .dailyTime:
            return .daily(at: state.editRecurrenceTimeOfDay)
        case .weekly:
            return .weekly(
                on: state.editRecurrenceWeekday,
                at: state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil
            )
        case .monthlyDay:
            return .monthly(
                on: state.editRecurrenceDayOfMonth,
                at: state.editRecurrenceHasExplicitTime ? state.editRecurrenceTimeOfDay : nil
            )
        }
    }

    func canAutoAssumeDailyDone(for state: State) -> Bool {
        state.canAutoAssumeDailyDone
    }

    func moveStep(_ stepID: UUID, by offset: Int, state: inout State) {
        guard let index = state.editRoutineSteps.firstIndex(where: { $0.id == stepID }) else { return }
        let targetIndex = index + offset
        guard state.editRoutineSteps.indices.contains(targetIndex) else { return }
        let step = state.editRoutineSteps.remove(at: index)
        state.editRoutineSteps.insert(step, at: targetIndex)
    }

    func appendStep(from draft: String, to currentSteps: [RoutineStep]) -> [RoutineStep] {
        guard let title = RoutineStep.normalizedTitle(draft) else { return currentSteps }
        return currentSteps + [RoutineStep(title: title)]
    }

    func appendChecklistItem(
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

    func scheduleModeRequiresChecklistItems(_ scheduleMode: RoutineScheduleMode) -> Bool {
        scheduleMode == .fixedIntervalChecklist || scheduleMode == .derivedFromChecklist
    }

    func hasDuplicateRoutineName(
        _ name: String,
        in context: ModelContext,
        excludingID: UUID
    ) throws -> Bool {
        guard let normalized = RoutineTask.normalizedName(name) else { return false }
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.contains { task in
            task.id != excludingID && RoutineTask.normalizedName(task.name) == normalized
        }
    }
}
