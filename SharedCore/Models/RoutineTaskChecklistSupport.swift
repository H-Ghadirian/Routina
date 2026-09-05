import Foundation

enum RoutineTaskDailyRoutineSupport {
    static func hasDailyRunoutChecklistItem(_ checklistItems: [RoutineChecklistItem]) -> Bool {
        checklistItems.contains { $0.intervalDays <= 1 }
    }

    static func isDailyRoutineForTaskList(
        scheduleMode: RoutineScheduleMode,
        recurrenceRule: RoutineRecurrenceRule,
        checklistItems: [RoutineChecklistItem]
    ) -> Bool {
        isDailyRoutineForTaskList(
            isOneOffTask: scheduleMode == .oneOff,
            scheduleMode: scheduleMode,
            recurrenceRule: recurrenceRule,
            hasDailyRunoutChecklistItem: hasDailyRunoutChecklistItem(checklistItems)
        )
    }

    static func isDailyRoutineForTaskList(
        isOneOffTask: Bool,
        scheduleMode: RoutineScheduleMode,
        recurrenceRule: RoutineRecurrenceRule,
        hasDailyRunoutChecklistItem: Bool
    ) -> Bool {
        guard !isOneOffTask,
            scheduleMode.usesRoutineCadence,
            recurrenceRule.isDaily
        else { return false }
        guard scheduleMode.isChecklistDrivenMode else { return true }
        return hasDailyRunoutChecklistItem
    }
}

enum RoutineTaskPlanningSupport {
    static func supportsStoredPlanning(
        scheduleMode: RoutineScheduleMode,
        recurrenceRule: RoutineRecurrenceRule,
        checklistItems: [RoutineChecklistItem],
        cadenceEnabled: Bool = true
    ) -> Bool {
        if scheduleMode.taskType == .routine, !cadenceEnabled {
            return true
        }
        return !RoutineTaskDailyRoutineSupport.isDailyRoutineForTaskList(
            scheduleMode: scheduleMode,
            recurrenceRule: recurrenceRule,
            checklistItems: checklistItems
        )
    }

    static func supportsStoredPlanning(
        scheduleMode: RoutineScheduleMode,
        cadenceEnabled: Bool = true,
        isDailyRoutine: Bool
    ) -> Bool {
        if scheduleMode.taskType == .routine, !cadenceEnabled {
            return true
        }
        return !isDailyRoutine
    }
}

extension RoutineTask {
    struct ChecklistRunoutUpdate: Equatable {
        var updatedItemCount: Int
        var didCompleteRoutine: Bool
    }

    struct ChecklistRunoutUndoUpdate: Equatable {
        var restoredItemCount: Int
        var removedCompletionAt: Date?
    }

    var hasChecklistItems: Bool {
        !checklistItems.isEmpty
    }

    var isChecklistDriven: Bool {
        scheduleMode.isChecklistDrivenMode && hasChecklistItems
    }

    var hasDailyRunoutChecklistItem: Bool {
        scheduleMode.isChecklistDrivenMode
            && RoutineTaskDailyRoutineSupport.hasDailyRunoutChecklistItem(checklistItems)
    }

    var isDailyRoutineForTaskList: Bool {
        guard usesEffectiveRoutineCadence else { return false }
        return RoutineTaskDailyRoutineSupport.isDailyRoutineForTaskList(
            scheduleMode: scheduleMode,
            recurrenceRule: recurrenceRule,
            checklistItems: checklistItems
        )
    }

    var supportsStoredPlanning: Bool {
        RoutineTaskPlanningSupport.supportsStoredPlanning(
            scheduleMode: scheduleMode,
            cadenceEnabled: cadenceEnabled,
            isDailyRoutine: isDailyRoutineForTaskList
        )
    }

    var isChecklistCompletionRoutine: Bool {
        scheduleMode.isChecklistCompletionMode && hasChecklistItems
    }

    var supportsOptionalChecklistProgress: Bool {
        hasChecklistItems
            && !scheduleMode.isChecklistDrivenMode
            && !scheduleMode.isChecklistCompletionMode
    }

    var completedChecklistItemCount: Int {
        completedChecklistItemCount(referenceDate: Date(), calendar: .current)
    }

    func completedChecklistItemCount(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        let validIDs = Set(checklistItems.map(\.id))
        return currentCompletedChecklistItemIDs(referenceDate: referenceDate, calendar: calendar)
            .intersection(validIDs)
            .count
    }

    var totalChecklistItemCount: Int {
        checklistItems.count
    }

    var incompleteOptionalChecklistItemCount: Int {
        guard supportsOptionalChecklistProgress else { return 0 }
        return max(0, totalChecklistItemCount - completedChecklistItemCount)
    }

    var blocksManualCompletionForIncompleteChecklist: Bool {
        incompleteOptionalChecklistItemCount > 0
    }

    var isChecklistInProgress: Bool {
        isChecklistInProgress(referenceDate: Date(), calendar: .current)
    }

    func isChecklistInProgress(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let completedCount = completedChecklistItemCount(referenceDate: referenceDate, calendar: calendar)
        return isChecklistCompletionRoutine
            && completedCount > 0
            && completedCount < totalChecklistItemCount
    }

    var nextPendingChecklistItemTitle: String? {
        nextPendingChecklistItemTitle(referenceDate: Date(), calendar: .current)
    }

    func nextPendingChecklistItemTitle(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard isChecklistCompletionRoutine else { return nil }
        let completedIDs = currentCompletedChecklistItemIDs(referenceDate: referenceDate, calendar: calendar)
        return checklistItems.first(where: { !completedIDs.contains($0.id) })?.title
    }

    func nextDueChecklistItem(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> RoutineChecklistItem? {
        guard isChecklistDriven else { return nil }
        return checklistItems.min {
            RoutineDateMath.dueDate(for: $0, referenceDate: referenceDate, calendar: calendar)
                < RoutineDateMath.dueDate(for: $1, referenceDate: referenceDate, calendar: calendar)
        }
    }

    func dueChecklistItems(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [RoutineChecklistItem] {
        guard isChecklistDriven else { return [] }
        let dueBoundary = calendar.startOfDay(for: referenceDate)
        return
            checklistItems
            .filter { item in
                let dueDate = RoutineDateMath.dueDate(for: item, referenceDate: referenceDate, calendar: calendar)
                return calendar.startOfDay(for: dueDate) <= dueBoundary
            }
            .sorted {
                RoutineDateMath.dueDate(for: $0, referenceDate: referenceDate, calendar: calendar)
                    < RoutineDateMath.dueDate(for: $1, referenceDate: referenceDate, calendar: calendar)
            }
    }

    func replaceChecklistItems(_ updatedItems: [RoutineChecklistItem]) {
        checklistItemsStorage = RoutineChecklistItemStorage.serialize(
            RoutineChecklistItem.sanitized(updatedItems, for: scheduleMode)
        )
        sanitizeChecklistProgress()
    }

    func shiftChecklistItems(by duration: TimeInterval) {
        guard duration > 0, hasChecklistItems else { return }
        checklistItems = checklistItems.map { item in
            RoutineChecklistItem(
                id: item.id,
                title: item.title,
                intervalDays: item.intervalDays,
                lastPurchasedAt: item.lastPurchasedAt?.addingTimeInterval(duration),
                undoLastPurchasedAt: item.undoLastPurchasedAt?.addingTimeInterval(duration),
                undoTaskLastDone: item.undoTaskLastDone?.addingTimeInterval(duration),
                undoTaskScheduleAnchor: item.undoTaskScheduleAnchor?.addingTimeInterval(duration),
                createdAt: item.createdAt.addingTimeInterval(duration)
            )
        }
    }

    func resetChecklistProgress() {
        completedChecklistItemIDsStorage = ""
        completedChecklistProgressStartedAt = nil
    }

    func isChecklistItemCompleted(_ itemID: UUID) -> Bool {
        isChecklistItemCompleted(itemID, referenceDate: Date(), calendar: .current)
    }

    func isChecklistItemCompleted(
        _ itemID: UUID,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        currentCompletedChecklistItemIDs(referenceDate: referenceDate, calendar: calendar).contains(itemID)
    }

    func resetStaleDailyChecklistProgressIfNeeded(
        referenceDate: Date,
        calendar: Calendar = .current
    ) {
        guard isChecklistCompletionRoutine,
            recurrenceRule.isDaily,
            !completedChecklistItemIDs.isEmpty,
            !hasCurrentDailyChecklistProgress(referenceDate: referenceDate, calendar: calendar)
        else {
            return
        }

        resetChecklistProgress()
    }

    func sanitizeChecklistProgress() {
        guard isChecklistCompletionRoutine || supportsOptionalChecklistProgress else {
            completedChecklistItemIDsStorage = ""
            completedChecklistProgressStartedAt = nil
            return
        }

        let validIDs = Set(checklistItems.map(\.id))
        let sanitizedIDs = completedChecklistItemIDs.intersection(validIDs)
        completedChecklistItemIDsStorage = RoutineChecklistProgressStorage.serialize(sanitizedIDs)
        if sanitizedIDs.isEmpty || !isChecklistCompletionRoutine {
            completedChecklistProgressStartedAt = nil
        }
    }

    private func currentCompletedChecklistItemIDs(
        referenceDate: Date,
        calendar: Calendar
    ) -> Set<UUID> {
        if isChecklistCompletionRoutine,
            let lastDone,
            calendar.isDate(lastDone, inSameDayAs: referenceDate)
        {
            return []
        }

        guard isChecklistCompletionRoutine,
            recurrenceRule.isDaily,
            !completedChecklistItemIDs.isEmpty
        else {
            return completedChecklistItemIDs
        }

        guard hasCurrentDailyChecklistProgress(referenceDate: referenceDate, calendar: calendar) else {
            return []
        }
        return completedChecklistItemIDs
    }

    private func hasCurrentDailyChecklistProgress(
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let completedChecklistProgressStartedAt else { return false }
        return calendar.isDate(completedChecklistProgressStartedAt, inSameDayAs: referenceDate)
    }
}
