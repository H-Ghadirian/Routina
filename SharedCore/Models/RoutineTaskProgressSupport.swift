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
        trackingCadenceEnabled: Bool = true
    ) -> Bool {
        if scheduleMode.taskType == .record {
            return trackingCadenceEnabled
        }
        return !RoutineTaskDailyRoutineSupport.isDailyRoutineForTaskList(
                scheduleMode: scheduleMode,
                recurrenceRule: recurrenceRule,
                checklistItems: checklistItems
            )
    }

    static func supportsStoredPlanning(
        scheduleMode: RoutineScheduleMode,
        trackingCadenceEnabled: Bool = true,
        isDailyRoutine: Bool
    ) -> Bool {
        if scheduleMode.taskType == .record {
            return trackingCadenceEnabled
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

    var hasSequentialSteps: Bool {
        !steps.isEmpty
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
            trackingCadenceEnabled: trackingCadenceEnabled,
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

    var isSoftIntervalRoutine: Bool {
        scheduleMode.isSoftIntervalRoutine
            || (scheduleMode.taskType == .record && scheduleMode.scheduleBehavior == .soft && trackingCadenceEnabled)
    }

    var surfacesSoftIntervalNudges: Bool {
        isSoftIntervalRoutine && (!isRecordTask || (trackingCadenceEnabled && trackingNudgesEnabled))
    }

    var usesEffectiveRoutineCadence: Bool {
        scheduleMode.usesRoutineCadence && (!isRecordTask || trackingCadenceEnabled)
    }

    var usesRollingScheduleAnchor: Bool {
        usesEffectiveRoutineCadence && (recurrenceRule.kind == .intervalDays || isChecklistDriven)
    }

    var completedSteps: Int {
        max(min(Int(completedStepCount), steps.count), 0)
    }

    var totalSteps: Int {
        steps.count
    }

    var isInProgress: Bool {
        hasSequentialSteps && completedSteps > 0 && completedSteps < totalSteps
    }

    var currentStepNumber: Int? {
        guard hasSequentialSteps, completedSteps < totalSteps else { return nil }
        return completedSteps + 1
    }

    var nextStepTitle: String? {
        guard hasSequentialSteps, completedSteps < steps.count else { return nil }
        return steps[completedSteps].title
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
        return checklistItems
            .filter { item in
                let dueDate = RoutineDateMath.dueDate(for: item, referenceDate: referenceDate, calendar: calendar)
                return calendar.startOfDay(for: dueDate) <= dueBoundary
            }
            .sorted {
                RoutineDateMath.dueDate(for: $0, referenceDate: referenceDate, calendar: calendar)
                    < RoutineDateMath.dueDate(for: $1, referenceDate: referenceDate, calendar: calendar)
            }
    }

    func replaceSteps(_ updatedSteps: [RoutineStep]) {
        let sanitized = RoutineStep.sanitized(updatedSteps)
        let previous = steps
        stepsStorage = RoutineStepStorage.serialize(sanitized)

        if sanitized.isEmpty {
            resetStepProgress()
            return
        }

        if sanitized != previous || Int(completedStepCount) > sanitized.count {
            resetStepProgress()
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

    func resetStepProgress() {
        completedStepCount = 0
        sequenceStartedAt = nil
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
        guard usesDailyChecklistCompletionProgress,
              !completedChecklistItemIDs.isEmpty,
              !hasCurrentDailyChecklistProgress(referenceDate: referenceDate, calendar: calendar)
        else {
            return
        }

        resetChecklistProgress()
    }

    @discardableResult
    func markChecklistItemsDone(
        _ itemIDs: Set<UUID>,
        doneAt: Date,
        calendar: Calendar = .current
    ) -> ChecklistRunoutUpdate {
        guard !isArchived(), isChecklistDriven, !itemIDs.isEmpty else {
            return ChecklistRunoutUpdate(updatedItemCount: 0, didCompleteRoutine: false)
        }

        var updatedCount = 0
        let updatedItems = checklistItems.map { item in
            guard itemIDs.contains(item.id) else { return item }
            updatedCount += 1
            return RoutineChecklistItem(
                id: item.id,
                title: item.title,
                intervalDays: item.intervalDays,
                lastPurchasedAt: doneAt,
                undoLastPurchasedAt: item.lastPurchasedAt,
                undoTaskLastDone: lastDone,
                undoTaskScheduleAnchor: scheduleAnchor,
                createdAt: item.createdAt
            )
        }

        guard updatedCount > 0 else {
            return ChecklistRunoutUpdate(updatedItemCount: 0, didCompleteRoutine: false)
        }
        checklistItems = updatedItems
        let didCompleteRoutine = dueChecklistItems(referenceDate: doneAt, calendar: calendar).isEmpty
        if didCompleteRoutine {
            recordCompletion(at: doneAt, calendar: calendar)
        }
        return ChecklistRunoutUpdate(updatedItemCount: updatedCount, didCompleteRoutine: didCompleteRoutine)
    }

    @discardableResult
    func undoChecklistItemRunoutDone(
        _ itemID: UUID,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> ChecklistRunoutUndoUpdate {
        guard !isArchived(), isChecklistDriven,
              let item = checklistItems.first(where: { $0.id == itemID }),
              let doneAt = item.lastPurchasedAt,
              calendar.isDate(doneAt, inSameDayAs: referenceDate) else {
            return ChecklistRunoutUndoUpdate(restoredItemCount: 0, removedCompletionAt: nil)
        }

        let currentCompletionAt = lastDone
        let previousLastDone = item.undoTaskLastDone
        let previousScheduleAnchor = item.undoTaskScheduleAnchor
        let shouldRemoveCompletion = currentCompletionAt.map { completionAt in
            completionAt != previousLastDone
                && calendar.isDate(completionAt, inSameDayAs: referenceDate)
        } ?? false
        let updatedItems = checklistItems.map { currentItem in
            guard currentItem.id == itemID else { return currentItem }
            return RoutineChecklistItem(
                id: currentItem.id,
                title: currentItem.title,
                intervalDays: currentItem.intervalDays,
                lastPurchasedAt: currentItem.undoLastPurchasedAt,
                undoLastPurchasedAt: nil,
                undoTaskLastDone: nil,
                undoTaskScheduleAnchor: nil,
                createdAt: currentItem.createdAt
            )
        }

        checklistItems = updatedItems
        lastDone = previousLastDone
        scheduleAnchor = previousScheduleAnchor
        return ChecklistRunoutUndoUpdate(
            restoredItemCount: 1,
            removedCompletionAt: shouldRemoveCompletion ? currentCompletionAt : nil
        )
    }

    @discardableResult
    func extendChecklistItemsRunout(
        _ itemIDs: Set<UUID>,
        byDays days: Int = 1,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        let clampedDays = max(days, 1)
        guard !isArchived(), isChecklistDriven, !itemIDs.isEmpty else { return 0 }

        var updatedCount = 0
        let updatedItems = checklistItems.map { item in
            guard itemIDs.contains(item.id) else { return item }
            let currentDueDate = RoutineDateMath.dueDate(
                for: item,
                referenceDate: referenceDate,
                calendar: calendar
            )
            guard let extendedDueDate = calendar.date(
                byAdding: .day,
                value: clampedDays,
                to: currentDueDate
            ),
            let shiftedAnchor = calendar.date(
                byAdding: .day,
                value: -RoutineChecklistItem.clampedIntervalDays(item.intervalDays),
                to: extendedDueDate
            ) else {
                return item
            }
            updatedCount += 1
            return RoutineChecklistItem(
                id: item.id,
                title: item.title,
                intervalDays: item.intervalDays,
                lastPurchasedAt: shiftedAnchor,
                undoLastPurchasedAt: item.undoLastPurchasedAt,
                undoTaskLastDone: item.undoTaskLastDone,
                undoTaskScheduleAnchor: item.undoTaskScheduleAnchor,
                createdAt: item.createdAt
            )
        }

        guard updatedCount > 0 else { return 0 }
        checklistItems = updatedItems
        return updatedCount
    }

    @discardableResult
    func markChecklistItemsPurchased(
        _ itemIDs: Set<UUID>,
        purchasedAt: Date
    ) -> Int {
        markChecklistItemsDone(
            itemIDs,
            doneAt: purchasedAt,
            calendar: .current
        ).updatedItemCount
    }

    @discardableResult
    func markChecklistItemCompleted(
        _ itemID: UUID,
        completedAt: Date,
        calendar: Calendar = .current
    ) -> RoutineAdvanceResult {
        guard !isArchived() else { return .ignoredPaused }
        guard isChecklistCompletionRoutine,
              checklistItems.contains(where: { $0.id == itemID }) else {
            return .ignoredAlreadyCompletedToday
        }

        resetStaleDailyChecklistProgressIfNeeded(referenceDate: completedAt, calendar: calendar)

        if let lastDone,
           calendar.isDate(lastDone, inSameDayAs: completedAt),
           !recurrenceRule.occursMoreThanOncePerDay {
            resetChecklistProgress()
            return .ignoredAlreadyCompletedToday
        }

        var updatedIDs = completedChecklistItemIDs
        let insertResult = updatedIDs.insert(itemID)
        guard insertResult.inserted else {
            return .advancedChecklist(
                completedItems: completedChecklistItemCount,
                totalItems: totalChecklistItemCount
            )
        }

        completedChecklistItemIDs = updatedIDs
        if usesDailyChecklistCompletionProgress {
            completedChecklistProgressStartedAt = completedAt
        }
        let completedCount = updatedIDs.count
        let totalCount = totalChecklistItemCount

        if completedCount < totalCount {
            return .advancedChecklist(completedItems: completedCount, totalItems: totalCount)
        }

        recordCompletion(at: completedAt, calendar: calendar)
        resetChecklistProgress()
        return .completedRoutine
    }

    @discardableResult
    func markOptionalChecklistItemCompleted(_ itemID: UUID) -> Bool {
        guard !isArchived(),
              supportsOptionalChecklistProgress,
              checklistItems.contains(where: { $0.id == itemID }) else {
            return false
        }

        var updatedIDs = completedChecklistItemIDs
        let insertResult = updatedIDs.insert(itemID)
        guard insertResult.inserted else { return false }
        completedChecklistItemIDs = updatedIDs
        return true
    }

    @discardableResult
    func unmarkChecklistItemCompleted(_ itemID: UUID) -> Bool {
        guard isChecklistCompletionRoutine || supportsOptionalChecklistProgress else { return false }

        var updatedIDs = completedChecklistItemIDs
        guard updatedIDs.remove(itemID) != nil else { return false }
        completedChecklistItemIDs = updatedIDs
        return true
    }

    @discardableResult
    func advance(completedAt: Date, calendar: Calendar = .current) -> RoutineAdvanceResult {
        guard !isArchived() else { return .ignoredPaused }

        if !hasSequentialSteps {
            if let lastDone,
               calendar.isDate(lastDone, inSameDayAs: completedAt),
               !recurrenceRule.occursMoreThanOncePerDay {
                return .ignoredAlreadyCompletedToday
            }
            recordCompletion(at: completedAt, calendar: calendar)
            resetOptionalRoutineChecklistProgressIfNeeded()
            return .completedRoutine
        }

        if completedSteps == 0,
           let lastDone,
           calendar.isDate(lastDone, inSameDayAs: completedAt),
           !recurrenceRule.occursMoreThanOncePerDay {
            return .ignoredAlreadyCompletedToday
        }

        if sequenceStartedAt == nil {
            sequenceStartedAt = completedAt
        }

        let nextCompletedStepCount = min(completedSteps + 1, totalSteps)
        if nextCompletedStepCount < totalSteps {
            completedStepCount = Int16(nextCompletedStepCount)
            return .advancedStep(completedSteps: nextCompletedStepCount, totalSteps: totalSteps)
        }

        recordCompletion(at: completedAt, calendar: calendar)
        resetStepProgress()
        resetOptionalRoutineChecklistProgressIfNeeded()
        return .completedRoutine
    }

    @discardableResult
    func recordFulfillment(at fulfilledAt: Date, calendar: Calendar = .current) -> Bool {
        guard canBeFulfilledByLinkedTask(referenceDate: fulfilledAt, calendar: calendar) else {
            return false
        }
        guard recurrenceRule.occursMoreThanOncePerDay
            || (lastDone.map({ !calendar.isDate($0, inSameDayAs: fulfilledAt) }) ?? true) else {
            return false
        }

        recordCompletion(at: fulfilledAt, calendar: calendar)
        resetStepProgress()
        resetChecklistProgress()
        resetOptionalRoutineChecklistProgressIfNeeded()
        return true
    }

    func canBeFulfilledByLinkedTask(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        !isOneOffTask
            && !hasSequentialSteps
            && !isChecklistDriven
            && !isArchived(referenceDate: referenceDate, calendar: calendar)
            && RoutineDateMath.canMarkDone(for: self, referenceDate: referenceDate, calendar: calendar)
    }

    func refreshScheduleAnchorAfterRemovingLatestCompletion(
        remainingLatestCompletion: Date?
    ) {
        if usesRollingScheduleAnchor {
            if isArchived() {
                if let remainingLatestCompletion {
                    scheduleAnchor = remainingLatestCompletion
                } else {
                    scheduleAnchor = pausedAt
                }
            } else {
                scheduleAnchor = remainingLatestCompletion
            }
            return
        }

        if isArchived() {
            scheduleAnchor = pausedAt ?? scheduleAnchor
        } else if scheduleAnchor == nil {
            scheduleAnchor = remainingLatestCompletion
        }
    }

    func preserveCurrentScheduleAnchorForBackfill(
        completedAt: Date,
        referenceDate: Date
    ) {
        guard usesRollingScheduleAnchor else { return }
        guard completedAt < referenceDate else { return }
        guard scheduleAnchor == nil else { return }
        guard let lastDone else { return }
        scheduleAnchor = lastDone
    }

    func finishOngoing(at finishedAt: Date) {
        recordCompletion(at: finishedAt)
        activityState = .idle
        ongoingSince = nil
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

    private var usesDailyChecklistCompletionProgress: Bool {
        isChecklistCompletionRoutine && recurrenceRule.isDaily
    }

    private func currentCompletedChecklistItemIDs(
        referenceDate: Date,
        calendar: Calendar
    ) -> Set<UUID> {
        if isChecklistCompletionRoutine,
           let lastDone,
           calendar.isDate(lastDone, inSameDayAs: referenceDate) {
            return []
        }

        guard usesDailyChecklistCompletionProgress,
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

    private func resetOptionalRoutineChecklistProgressIfNeeded() {
        guard supportsOptionalChecklistProgress, !isOneOffTask else { return }
        resetChecklistProgress()
    }

    private func shouldUpdateLastDone(with candidate: Date) -> Bool {
        guard let lastDone else { return true }
        return candidate > lastDone
    }

    private func shouldUpdateScheduleAnchor(with candidate: Date) -> Bool {
        guard let scheduleAnchor else { return true }
        return candidate > scheduleAnchor
    }

    private func recordCompletion(at completedAt: Date, calendar: Calendar = .current) {
        guard shouldUpdateLastDone(with: completedAt) else { return }
        lastDone = completedAt
        canceledAt = nil
        activityState = .idle
        ongoingSince = nil
        if usesRollingScheduleAnchor && shouldUpdateScheduleAnchor(with: completedAt) {
            scheduleAnchor = completedAt
        }
    }
}
