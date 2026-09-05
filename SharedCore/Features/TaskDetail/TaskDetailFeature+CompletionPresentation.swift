import Foundation

extension TaskDetailFeature.State {
    var isSelectedDateDone: Bool {
        let calendar = Calendar.current
        let day = resolvedSelectedDate
        if RoutineDateMath.usesExactTimedOccurrences(for: task) {
            guard let occurrence = completionTargetDate ?? selectedScheduledOccurrenceDate else { return false }
            guard !hasPendingLocalRemoval(on: occurrence, calendar: calendar) else { return false }
            return logs.contains {
                guard let timestamp = $0.timestamp else { return false }
                return $0.kind.resolvesDoneDate
                    && RoutineOccurrenceIdentity.matches(
                        timestamp,
                        occurrence,
                        for: task,
                        calendar: calendar
                    )
            }
                || task.lastDone.map {
                    RoutineOccurrenceIdentity.matches($0, occurrence, for: task, calendar: calendar)
                } == true
        }
        guard !hasPendingLocalRemoval(on: day, calendar: calendar) else { return false }
        return logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return $0.kind.resolvesDoneDate && calendar.isDate(timestamp, inSameDayAs: day)
        }
            || task.lastDone.map { calendar.isDate($0, inSameDayAs: day) } == true
    }

    var isSelectedDateCanceled: Bool {
        let calendar = Calendar.current
        let day = resolvedSelectedDate
        if RoutineDateMath.usesExactTimedOccurrences(for: task) {
            guard let occurrence = completionTargetDate ?? selectedScheduledOccurrenceDate else { return false }
            return logs.contains {
                guard let timestamp = $0.timestamp else { return false }
                return $0.kind == .canceled
                    && RoutineOccurrenceIdentity.matches(
                        timestamp,
                        occurrence,
                        for: task,
                        calendar: calendar
                    )
            }
                || task.canceledAt.map {
                    RoutineOccurrenceIdentity.matches($0, occurrence, for: task, calendar: calendar)
                } == true
        }
        return logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return $0.kind == .canceled && calendar.isDate(timestamp, inSameDayAs: day)
        }
            || task.canceledAt.map { calendar.isDate($0, inSameDayAs: day) } == true
    }

    var isSelectedDateTerminal: Bool {
        isSelectedDateDone || isSelectedDateCanceled
    }

    var isSelectedDateAssumedDone: Bool {
        !isSelectedDateTerminal
            && RoutineAssumedCompletion.isAssumedDone(
                for: task,
                on: resolvedSelectedDate,
                logs: logs
            )
    }

    var completionStatusPillPhase: TaskDetailCompletionStatusPillPhase? {
        if isSelectedDateAssumedDone {
            return .assumed
        }
        guard let acknowledgement = assumedCompletionAcknowledgement,
            canUndoSelectedDate,
            Calendar.current.isDate(acknowledgement.day, inSameDayAs: resolvedSelectedDate)
        else {
            return nil
        }
        return .confirmed
    }

    var assumedCompletionStatusHeightReservationText: String? {
        guard completionStatusPillPhase == .confirmed else { return nil }
        return assumedCompletionAcknowledgement?.previousStatusTitle
    }

    var pastAssumedDates: [Date] {
        RoutineAssumedCompletion.pastAssumedDates(for: task, logs: logs)
    }

    var confirmableAssumedDates: [Date] {
        RoutineAssumedCompletion.assumedDates(for: task, logs: logs)
    }

    var shouldShowBulkConfirmAssumedDays: Bool {
        !RoutineAssumedCompletion.requiresIndividualAssumedCompletionConfirmation(for: task)
            && !task.isArchived()
            && !pastAssumedDates.isEmpty
    }

    var bulkConfirmAssumedDaysTitle: String {
        let count = confirmableAssumedDates.count
        return count == 1 ? "Confirm 1 assumed day" : "Confirm \(count) assumed days"
    }

    var completedLogCount: Int {
        logs.filter { $0.kind.resolvesDoneDate }.count
    }

    var canceledLogCount: Int {
        logs.filter { $0.kind == .canceled }.count
    }

    var checklistDueItemCount: Int {
        dueChecklistItems(referenceDate: resolvedSelectedDate).count
    }

    var isSelectedDateInFuture: Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: resolvedSelectedDate) > calendar.startOfDay(for: Date())
    }

    var isStepRoutineOffToday: Bool {
        task.hasSequentialSteps && !Calendar.current.isDateInToday(resolvedSelectedDate)
    }

    var linkedPlaceSummary: RoutinePlaceSummary? {
        guard let placeID = task.placeIDs.first else { return nil }
        return availablePlaces.first(where: { $0.id == placeID })
    }

    var resolvedRelationships: [RoutineTaskResolvedRelationship] {
        RoutineTask.resolvedRelationships(for: task, within: availableRelationshipTasks)
    }

    /// The complete preloaded catalog used when a person chooses a new task to
    /// link from Task Details. `availableRelationshipTasks` remains limited to
    /// existing relationship neighbors so normal detail presentation stays
    /// lightweight.
    var linkableRelationshipTasks: [RoutineTaskRelationshipCandidate] {
        editAvailableRelationshipTasks.isEmpty
            ? availableRelationshipTasks
            : editAvailableRelationshipTasks
    }

    var groupedResolvedRelationships: [(kind: RoutineTaskRelationshipKind, items: [RoutineTaskResolvedRelationship])] {
        let grouped = Dictionary(grouping: resolvedRelationships, by: \.kind)
        return RoutineTaskRelationshipKind.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { kind in
                guard let items = grouped[kind], !items.isEmpty else { return nil }
                return (kind: kind, items: items)
            }
    }

    var pendingManualCompletionTargets: [RoutineTaskResolvedRelationship] {
        pendingManualCompletion?.targets ?? []
    }

    func manualCompletionTargets(for _: Date) -> [RoutineTaskResolvedRelationship] {
        var resolvedByTaskID: [UUID: RoutineTaskResolvedRelationship] = [:]
        let candidateByID = RoutineTaskRelationshipCandidate.lookupByID(availableRelationshipTasks)

        func appendCandidate(
            _ candidate: RoutineTaskRelationshipCandidate,
            kind: RoutineTaskRelationshipKind
        ) {
            guard candidate.canBeFulfilledByLinkedTask,
                candidate.status.allowsManualFulfillmentPrompt
            else {
                return
            }
            resolvedByTaskID[candidate.id] = RoutineTaskResolvedRelationship(
                taskID: candidate.id,
                taskName: candidate.displayName,
                taskEmoji: candidate.emoji,
                kind: kind,
                status: candidate.status
            )
        }

        for relationship in task.relationships where relationship.kind == .canComplete {
            guard let candidate = candidateByID[relationship.targetTaskID] else { continue }
            appendCandidate(candidate, kind: relationship.kind)
        }

        for candidate in availableRelationshipTasks {
            var inverseSourceKind: RoutineTaskRelationshipKind?
            for relationship in candidate.relationships where relationship.targetTaskID == task.id {
                switch relationship.kind {
                case .canBeCompletedBy:
                    inverseSourceKind = .canComplete
                default:
                    continue
                }
                break
            }
            guard let inverseSourceKind else {
                continue
            }
            appendCandidate(candidate, kind: inverseSourceKind)
        }

        return resolvedByTaskID.values.sorted {
            $0.taskName.localizedCaseInsensitiveCompare($1.taskName) == .orderedAscending
        }
    }

    var blockingRelationships: [RoutineTaskResolvedRelationship] {
        resolvedRelationships.filter { $0.kind == .blockedBy }
    }

    /// True when at least one `.blockedBy` prerequisite has not handed off a
    /// completion newer than this task's latest completion.
    var hasActiveRelationshipBlocker: Bool {
        RoutineTaskRelationshipResolution.hasActiveBlocker(
            for: task,
            within: availableRelationshipTasks,
            dependentLatestCompletionAt: latestRecordedCompletion
        )
    }

    /// The state Task Details should present after applying relationship-backed
    /// availability. The stored workflow state remains unchanged so resolving
    /// the prerequisite restores the person's previous Ready/In Progress state.
    var effectiveTodoState: TodoState? {
        guard let todoState = task.todoState else { return nil }
        guard hasActiveRelationshipBlocker else { return todoState }

        switch todoState {
        case .ready, .inProgress:
            return .blocked
        case .blocked, .done, .paused:
            return todoState
        }
    }

    var isTodoStateDerivedFromRelationshipBlocker: Bool {
        hasActiveRelationshipBlocker
            && effectiveTodoState == .blocked
            && task.todoState != .blocked
    }

    /// Ready and In Progress cannot be selected while an unresolved confirmed
    /// prerequisite still makes the task unavailable. Paused and Done remain
    /// valid lifecycle choices, with Done retaining its confirmation step.
    var selectableTodoStates: [TodoState] {
        guard hasActiveRelationshipBlocker else { return TodoState.allCases }
        return TodoState.allCases.filter { state in
            state == .blocked || state == .done || state == .paused
        }
    }

    var blockerSummaryText: String {
        if hasActiveRelationshipBlocker {
            let count = blockingRelationships.filter { rel in
                rel.status != .doneToday && rel.status != .completedOneOff && rel.status != .canceledOneOff
            }.count
            if count == 1,
                let blocker = blockingRelationships.first(where: { rel in
                    rel.status != .doneToday && rel.status != .completedOneOff && rel.status != .canceledOneOff
                })
            {
                return "Blocked by \"\(blocker.taskName)\". Complete that task first."
            }
            return "Blocked by \(count) incomplete tasks. Complete them first."
        }
        let count = blockingRelationships.count
        if count == 1, let blocker = blockingRelationships.first {
            return "Blocked by \(blocker.taskName). You can still mark this done, but it may be worth checking that task first."
        }
        return "Blocked by \(count) tasks. You can still mark this done, but it may be worth checking them first."
    }

    var canUndoSelectedDate: Bool {
        guard !isChecklistDrivenFromStoredItems, isSelectedDateTerminal else {
            return false
        }
        if !task.isOneOffTask,
            !task.usesEffectiveRoutineCadence,
            Calendar.current.isDateInToday(resolvedSelectedDate)
        {
            return false
        }
        return true
    }

    var completionButtonAction: TaskDetailFeature.Action {
        if canUndoSelectedDate {
            return .requestUndoSelectedDateCompletion
        }
        if task.usesOngoingLifecycle && task.isOngoing {
            return .finishOngoingTapped
        }
        if task.isMultiDayRoutine {
            return .startOngoingTapped
        }
        return .markAsDone
    }

    var completionButtonSystemImage: String? {
        if canUndoSelectedDate { return "arrow.uturn.backward" }
        if task.isMultiDayRoutine && task.isOngoing { return "stop.circle.fill" }
        if task.isMultiDayRoutine && !task.isOngoing { return "play.circle.fill" }
        return nil
    }

    var isCompletionButtonDisabled: Bool {
        guard !canUndoSelectedDate else { return false }
        if task.usesOngoingLifecycle && task.isOngoing {
            if task.isMultiDayRoutine,
                let ongoingSince = task.ongoingSince
            {
                return Calendar.current.startOfDay(for: resolvedSelectedDate) < Calendar.current.startOfDay(for: ongoingSince)
            }
            return false
        }
        if task.isMultiDayRoutine {
            return task.isArchived()
        }
        if task.isCompletedOneOff || task.isCanceledOneOff {
            return true
        }
        if task.isOneOffTask && hasActiveRelationshipBlocker {
            return true
        }
        if isSelectedDateAssumedDone {
            return task.isArchived()
        }
        if blocksManualCompletionForIncompleteChecklist {
            return true
        }
        if isChecklistCompletionFromStoredItems {
            return true
        }
        if isChecklistDrivenFromStoredItems {
            return task.isArchived()
                || isSelectedDateInFuture
                || checklistDueItemCount == 0
        }
        if RoutineDateMath.usesExactTimedOccurrences(for: task) {
            guard let completionTargetDate else { return true }
            return task.isArchived()
                || !RoutineDateMath.canMarkSelectedExactTimedOccurrenceDone(
                    for: task,
                    completionDate: completionTargetDate,
                    referenceDate: Date(),
                    logs: logs,
                    calendar: .current
                )
                || isStepRoutineOffToday
        }
        return isSelectedDateInFuture || task.isArchived() || isStepRoutineOffToday
    }
}
