import Foundation

extension RoutineTask {
    var hasSequentialSteps: Bool {
        !steps.isEmpty
    }

    var hasChecklistItems: Bool {
        !checklistItems.isEmpty
    }

    var isChecklistDriven: Bool {
        scheduleMode == .derivedFromChecklist && hasChecklistItems
    }

    var isChecklistCompletionRoutine: Bool {
        scheduleMode == .fixedIntervalChecklist && hasChecklistItems
    }

    var isSoftIntervalRoutine: Bool {
        scheduleMode == .softInterval
    }

    var usesRollingScheduleAnchor: Bool {
        recurrenceRule.kind == .intervalDays || isChecklistDriven
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
        let validIDs = Set(checklistItems.map(\.id))
        return completedChecklistItemIDs.intersection(validIDs).count
    }

    var totalChecklistItemCount: Int {
        checklistItems.count
    }

    var isChecklistInProgress: Bool {
        isChecklistCompletionRoutine
            && completedChecklistItemCount > 0
            && completedChecklistItemCount < totalChecklistItemCount
    }

    var nextPendingChecklistItemTitle: String? {
        guard isChecklistCompletionRoutine else { return nil }
        return checklistItems.first(where: { !completedChecklistItemIDs.contains($0.id) })?.title
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
        checklistItemsStorage = RoutineChecklistItemStorage.serialize(updatedItems)
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
    }

    func isChecklistItemCompleted(_ itemID: UUID) -> Bool {
        completedChecklistItemIDs.contains(itemID)
    }

    @discardableResult
    func markChecklistItemsPurchased(
        _ itemIDs: Set<UUID>,
        purchasedAt: Date
    ) -> Int {
        guard !isArchived(), isChecklistDriven, !itemIDs.isEmpty else { return 0 }

        var updatedCount = 0
        let updatedItems = checklistItems.map { item in
            guard itemIDs.contains(item.id) else { return item }
            updatedCount += 1
            return RoutineChecklistItem(
                id: item.id,
                title: item.title,
                intervalDays: item.intervalDays,
                lastPurchasedAt: purchasedAt,
                createdAt: item.createdAt
            )
        }

        guard updatedCount > 0 else { return 0 }
        checklistItems = updatedItems
        recordCompletion(at: purchasedAt)
        return updatedCount
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

        if completedChecklistItemIDs.isEmpty,
           let lastDone,
           calendar.isDate(lastDone, inSameDayAs: completedAt) {
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
    func unmarkChecklistItemCompleted(_ itemID: UUID) -> Bool {
        guard isChecklistCompletionRoutine else { return false }

        var updatedIDs = completedChecklistItemIDs
        guard updatedIDs.remove(itemID) != nil else { return false }
        completedChecklistItemIDs = updatedIDs
        return true
    }

    @discardableResult
    func advance(completedAt: Date, calendar: Calendar = .current) -> RoutineAdvanceResult {
        guard !isArchived() else { return .ignoredPaused }

        if !hasSequentialSteps {
            if let lastDone, calendar.isDate(lastDone, inSameDayAs: completedAt) {
                return .ignoredAlreadyCompletedToday
            }
            recordCompletion(at: completedAt, calendar: calendar)
            return .completedRoutine
        }

        if completedSteps == 0,
           let lastDone,
           calendar.isDate(lastDone, inSameDayAs: completedAt) {
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
        return .completedRoutine
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
    }

    func sanitizeChecklistProgress() {
        guard isChecklistCompletionRoutine else {
            completedChecklistItemIDsStorage = ""
            return
        }

        let validIDs = Set(checklistItems.map(\.id))
        let sanitizedIDs = completedChecklistItemIDs.intersection(validIDs)
        completedChecklistItemIDsStorage = RoutineChecklistProgressStorage.serialize(sanitizedIDs)
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
        advanceReminderAfterCompletion(completedAt: completedAt, calendar: calendar)
    }

    private func advanceReminderAfterCompletion(completedAt: Date, calendar: Calendar) {
        guard !isOneOffTask, let reminderAt else { return }
        guard let nextReminderAt = nextReminderDateAfterCompletion(
            completedAt: completedAt,
            previousReminderAt: reminderAt,
            calendar: calendar
        ) else {
            return
        }
        self.reminderAt = nextReminderAt
    }

    private func nextReminderDateAfterCompletion(
        completedAt: Date,
        previousReminderAt: Date,
        calendar: Calendar
    ) -> Date? {
        var candidate = previousReminderAt
        var remainingAdvances = 10_000

        repeat {
            guard let nextCandidate = nextReminderOccurrence(after: candidate, calendar: calendar) else {
                return nil
            }
            candidate = nextCandidate
            remainingAdvances -= 1
        } while candidate <= completedAt && remainingAdvances > 0

        return candidate > completedAt ? candidate : nil
    }

    private func nextReminderOccurrence(after date: Date, calendar: Calendar) -> Date? {
        switch recurrenceRule.kind {
        case .intervalDays:
            return calendar.date(
                byAdding: .day,
                value: max(recurrenceRule.interval, 1),
                to: date
            )

        case .dailyTime:
            return calendar.date(byAdding: .day, value: 1, to: date)

        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)

        case .monthlyDay:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}
