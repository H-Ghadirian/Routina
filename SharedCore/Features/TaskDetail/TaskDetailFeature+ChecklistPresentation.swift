import Foundation

extension TaskDetailFeature.State {
    func isChecklistItemMarkedDone(_ item: RoutineChecklistItem) -> Bool {
        if isChecklistDrivenFromStoredItems {
            return TaskDetailChecklistPresentation.isRunoutItemMarkedDone(
                item,
                referenceDate: resolvedSelectedDate,
                calendar: .current
            )
        }
        if isSelectedChecklistCompletionDateDone {
            return true
        }
        return task.isChecklistItemCompleted(item.id, referenceDate: resolvedSelectedDate)
    }

    var supportsOptionalChecklistProgressFromStoredItems: Bool {
        hasStoredChecklistItems
            && !task.scheduleMode.isChecklistDrivenMode
            && !task.scheduleMode.isChecklistCompletionMode
    }

    var totalChecklistItemCount: Int {
        detailChecklistItems.count
    }

    var blocksManualCompletionForIncompleteChecklist: Bool {
        supportsOptionalChecklistProgressFromStoredItems
            && totalChecklistItemCount > completedChecklistItemCount(referenceDate: Date())
    }

    func completedChecklistItemCount(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        let validIDs = Set(detailChecklistItems.map(\.id))
        return currentCompletedChecklistItemIDs(referenceDate: referenceDate, calendar: calendar)
            .intersection(validIDs)
            .count
    }

    func isChecklistInProgress(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let completedCount = completedChecklistItemCount(referenceDate: referenceDate, calendar: calendar)
        return isChecklistCompletionFromStoredItems
            && completedCount > 0
            && completedCount < totalChecklistItemCount
    }

    func nextDueChecklistItem(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> RoutineChecklistItem? {
        guard isChecklistDrivenFromStoredItems else { return nil }
        return detailChecklistItems.min {
            RoutineDateMath.dueDate(for: $0, referenceDate: referenceDate, calendar: calendar)
                < RoutineDateMath.dueDate(for: $1, referenceDate: referenceDate, calendar: calendar)
        }
    }

    func dueChecklistItems(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [RoutineChecklistItem] {
        guard isChecklistDrivenFromStoredItems else { return [] }
        let dueBoundary = calendar.startOfDay(for: referenceDate)
        return
            detailChecklistItems
            .filter { item in
                let dueDate = RoutineDateMath.dueDate(for: item, referenceDate: referenceDate, calendar: calendar)
                return calendar.startOfDay(for: dueDate) <= dueBoundary
            }
            .sorted {
                RoutineDateMath.dueDate(for: $0, referenceDate: referenceDate, calendar: calendar)
                    < RoutineDateMath.dueDate(for: $1, referenceDate: referenceDate, calendar: calendar)
            }
    }

    func nextPendingChecklistItemTitle(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard isChecklistCompletionFromStoredItems else { return nil }
        let completedIDs = currentCompletedChecklistItemIDs(referenceDate: referenceDate, calendar: calendar)
        return detailChecklistItems.first(where: { !completedIDs.contains($0.id) })?.title
    }

    private func currentCompletedChecklistItemIDs(
        referenceDate: Date,
        calendar: Calendar
    ) -> Set<UUID> {
        if isChecklistCompletionFromStoredItems,
            let lastDone = task.lastDone,
            calendar.isDate(lastDone, inSameDayAs: referenceDate)
        {
            return []
        }

        guard isChecklistCompletionFromStoredItems && task.recurrenceRule.isDaily,
            !task.completedChecklistItemIDs.isEmpty
        else {
            return task.completedChecklistItemIDs
        }

        guard let progressStartedAt = task.completedChecklistProgressStartedAt,
            calendar.isDate(progressStartedAt, inSameDayAs: referenceDate)
        else {
            return []
        }
        return task.completedChecklistItemIDs
    }
}
