import Foundation

// Derived, view-facing state computed from `TaskDetailFeature.State`.
// Keep pure (no SwiftUI types) so these can be exercised from tests and used
// by any platform view via `store.<property>` dynamic member lookup.
extension TaskDetailFeature.State {
    mutating func refreshChecklistItemsCache() {
        let storage = task.checklistItemsStorage
        guard checklistItemsCache.storage != storage else { return }
        checklistItemsCache.items = RoutineChecklistItemStorage.deserialize(storage)
        checklistItemsCache.storage = storage
    }

    var detailChecklistItems: [RoutineChecklistItem] {
        if checklistItemsCache.storage == task.checklistItemsStorage {
            return checklistItemsCache.items
        }
        return task.checklistItems
    }

    /// Resolves the optional `selectedDate` to a concrete start-of-day value.
    var resolvedSelectedDate: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: selectedDate ?? Date())
    }

    var hasStoredChecklistItems: Bool {
        !detailChecklistItems.isEmpty
    }

    var isChecklistDrivenFromStoredItems: Bool {
        task.scheduleMode.isChecklistDrivenMode && hasStoredChecklistItems
    }

    var isChecklistCompletionFromStoredItems: Bool {
        task.scheduleMode.isChecklistCompletionMode && hasStoredChecklistItems
    }

    var selectedScheduledOccurrenceDate: Date? {
        RoutineDateMath.scheduledOccurrence(
            for: task,
            on: resolvedSelectedDate,
            calendar: .current
        )
    }

    var validSelectedOccurrenceDate: Date? {
        guard let selectedOccurrenceDate,
            isScheduledOccurrenceOnSelectedDay(selectedOccurrenceDate)
        else {
            return nil
        }
        return selectedOccurrenceDate
    }

    func isScheduledOccurrenceOnSelectedDay(
        _ occurrence: Date,
        calendar: Calendar = .current
    ) -> Bool {
        RoutineDateMath.scheduledOccurrences(
            for: task,
            on: resolvedSelectedDate,
            calendar: calendar
        ).contains {
            RoutineOccurrenceIdentity.matches(
                $0,
                occurrence,
                for: task,
                calendar: calendar
            )
        }
    }

    var completionTargetDate: Date? {
        if let validSelectedOccurrenceDate {
            return validSelectedOccurrenceDate
        }
        return RoutineDateMath.completionTargetDate(
            for: task,
            selectedDay: resolvedSelectedDate,
            referenceDate: Date(),
            calendar: .current
        )
    }

    var selectedDayOccurrences: [TaskDetailOccurrencePresentation] {
        TaskDetailOccurrencePresentation.items(
            for: task,
            on: resolvedSelectedDate,
            selectedOccurrence: validSelectedOccurrenceDate,
            referenceDate: Date(),
            logs: logs,
            calendar: .current
        )
    }

    var selectedCalendarOccurrence: TaskDetailOccurrencePresentation? {
        let occurrences = TaskDetailOccurrencePresentation.allItems(
            for: task,
            on: resolvedSelectedDate,
            selectedOccurrence: validSelectedOccurrenceDate,
            referenceDate: Date(),
            logs: logs,
            calendar: .current
        )
        guard occurrences.count == 1 else { return nil }
        return occurrences.first
    }

    func occurrencePresentation(
        for occurrence: Date
    ) -> TaskDetailOccurrencePresentation? {
        TaskDetailOccurrencePresentation.allItems(
            for: task,
            on: resolvedSelectedDate,
            selectedOccurrence: validSelectedOccurrenceDate,
            referenceDate: Date(),
            logs: logs,
            calendar: .current
        ).first {
            RoutineOccurrenceIdentity.matches(
                $0.occurrence,
                occurrence,
                for: task,
                calendar: .current
            )
        }
    }

    var missedExactTimedOccurrenceDate: Date? {
        RoutineDateMath.unresolvedMissedExactTimedOccurrenceDate(
            for: task,
            referenceDate: Date(),
            logs: logs
        )
    }

    var missedOccurrenceReviewPresentation: TaskDetailMissedOccurrenceReview? {
        missedOccurrenceReviewPresentation(referenceDate: Date())
    }

    func missedOccurrenceReviewPresentation(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> TaskDetailMissedOccurrenceReview? {
        guard !task.isChecklistDriven,
            !task.hasSequentialSteps,
            !task.isMultiDayRoutine
        else {
            return nil
        }
        guard
            let occurrence = RoutineDateMath.unresolvedMissedExactTimedOccurrenceDate(
                for: task,
                referenceDate: referenceDate,
                logs: logs,
                calendar: calendar
            )
        else {
            return nil
        }
        let upcomingOccurrence = RoutineDateMath.upcomingDueDate(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return TaskDetailMissedOccurrenceReview(
            occurrence: occurrence,
            nextOccurrence: upcomingOccurrence == .distantFuture ? nil : upcomingOccurrence,
            timeRange: task.recurrenceRule.timeRange
        )
    }
}
