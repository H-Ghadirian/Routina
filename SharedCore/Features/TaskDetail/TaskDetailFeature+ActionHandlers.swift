import ComposableArchitecture
import Foundation

extension TaskDetailFeature {
    func statusMutationHandler() -> TaskDetailStatusMutationHandler {
        TaskDetailStatusMutationHandler(
            now: { now },
            matrixPriority: { importance, urgency in
                matrixPriority(importance: importance, urgency: urgency)
            },
            appendLocalTodoStateChange: { task, previousStateTitle, newStateTitle in
                appendLocalTodoStateChange(
                    to: task,
                    previousStateTitle: previousStateTitle,
                    newStateTitle: newStateTitle
                )
            },
            refreshTaskView: { state in
                refreshTaskView(&state)
            },
            updateDerivedState: { state in
                updateDerivedState(&state)
            }
        )
    }

    func statusActionHandler() -> TaskDetailStatusActionHandler {
        TaskDetailStatusActionHandler(
            mutationHandler: statusMutationHandler(),
            markAsDone: { state in
                reduce(into: &state, action: .markAsDone)
            },
            persistTodoStateChange: { request in
                handleTodoStateChanged(
                    taskID: request.taskID,
                    rawValue: request.rawValue,
                    pausedAt: request.pausedAt,
                    clearSnoozed: request.clearSnoozed,
                    previousStateTitle: request.previousStateTitle,
                    newStateTitle: request.newStateTitle
                )
            },
            persistPressureChange: { mutation in
                handlePressureChanged(taskID: mutation.taskID, pressure: mutation.pressure)
            },
            persistThinkingNeededChange: { mutation in
                handleThinkingNeededChanged(
                    taskID: mutation.taskID,
                    thinkingNeeded: mutation.thinkingNeeded
                )
            },
            persistMatrixPositionChange: { mutation in
                handleMatrixPositionChanged(
                    taskID: mutation.taskID,
                    importance: mutation.importance,
                    urgency: mutation.urgency,
                    priority: mutation.priority,
                    hasExplicitImportance: mutation.hasExplicitImportance,
                    hasExplicitUrgency: mutation.hasExplicitUrgency
                )
            }
        )
    }

    func editDraftMutationHandler() -> TaskDetailEditDraftMutationHandler {
        TaskDetailEditDraftMutationHandler(
            matrixPriority: { importance, urgency in
                matrixPriority(importance: importance, urgency: urgency)
            },
            refreshTaskView: { state in
                refreshTaskView(&state)
            }
        )
    }

    func basicEditActionHandler() -> TaskDetailBasicEditActionHandler {
        TaskDetailBasicEditActionHandler(
            draftMutationHandler: editDraftMutationHandler()
        )
    }

    func sanitizeEditTemporalWeightRule(_ state: inout State) {
        guard let rule = state.editTemporalWeightRule else { return }
        guard
            RoutineTaskTemporalWeightResolver.supportsTemporalWeight(
                scheduleMode: state.editScheduleMode,
                cadenceEnabled: state.editScheduleMode.taskType == .todo
                    ? true
                    : state.editCadenceEnabled
            )
        else {
            state.editTemporalWeightRule = nil
            return
        }
        state.editTemporalWeightRule = rule.sanitized(
            baseImportance: state.editImportance,
            baseUrgency: state.editUrgency,
            basePressure: state.editPressure,
            maximumBeforeDueDays: state.candidateRecurrenceDraft.maximumTemporalWeightBeforeDueDays
        )
    }

    func sanitizeEditTaskLadderEntryWindow(_ state: inout State) {
        state.editTaskLadderEntryWindow = RoutineTaskLadderEntryResolver.sanitizedWindow(
            state.editTaskLadderEntryWindow,
            scheduleMode: state.editScheduleMode,
            cadenceEnabled: state.editScheduleMode.taskType == .todo
                ? true
                : state.editCadenceEnabled,
            hasDeadline: state.editDeadline != nil,
            maximumBeforeDueDays: state.editScheduleMode.taskType == .todo
                ? nil
                : state.candidateRecurrenceDraft.maximumTemporalWeightBeforeDueDays
        )
    }

    func tagGoalRelationshipEditActionHandler() -> TaskDetailTagGoalRelationshipEditActionHandler {
        TaskDetailTagGoalRelationshipEditActionHandler(
            draftMutationHandler: editDraftMutationHandler()
        )
    }

    func recurrenceEditActionHandler() -> TaskDetailRecurrenceEditActionHandler {
        TaskDetailRecurrenceEditActionHandler(
            now: { now },
            calendar: calendar
        )
    }

    func stepChecklistEditActionHandler() -> TaskDetailStepChecklistEditActionHandler {
        TaskDetailStepChecklistEditActionHandler(now: { now }, calendar: { calendar })
    }

    func editContextActionHandler() -> TaskDetailEditContextActionHandler {
        TaskDetailEditContextActionHandler()
    }

    func dialogLifecycleActionHandler() -> TaskDetailDialogLifecycleActionHandler {
        TaskDetailDialogLifecycleActionHandler(
            calendar: calendar,
            syncEditFormFromTask: { state in
                syncEditFormFromTask(&state)
            },
            loadEditContext: { taskID in
                loadEditContext(excluding: taskID)
            }
        )
    }

    func routineLifecycleActionHandler() -> TaskDetailRoutineLifecycleActionHandler {
        TaskDetailRoutineLifecycleActionHandler(
            now: { now },
            calendar: calendar,
            refreshTaskView: { state in
                refreshTaskView(&state)
            },
            updateDerivedState: { state in
                updateDerivedState(&state)
            },
            upsertLocalLog: { date, state in
                upsertLocalLog(at: date, in: &state)
            },
            persistPause: { taskID, pausedAt, pauseUntil in
                handlePauseRoutine(taskID: taskID, pausedAt: pausedAt, pauseUntil: pauseUntil)
            },
            persistNotToday: { taskID, snoozedUntil in
                handleNotTodayRoutine(taskID: taskID, snoozedUntil: snoozedUntil)
            },
            persistResume: { taskID, resumedAt in
                handleResumeRoutine(taskID: taskID, resumedAt: resumedAt)
            },
            persistStartOngoing: { taskID, startedAt in
                handleStartOngoing(taskID: taskID, startedAt: startedAt)
            },
            persistFinishOngoing: { taskID, finishedAt in
                handleFinishOngoing(taskID: taskID, finishedAt: finishedAt)
            }
        )
    }

    func completionLogActionHandler() -> TaskDetailCompletionLogActionHandler {
        TaskDetailCompletionLogActionHandler(
            now: { now },
            calendar: calendar,
            resolvedSelectedDay: { selectedDate in
                resolvedSelectedDay(for: selectedDate)
            },
            removePendingLocalCompletion: { day, state in
                removePendingLocalCompletion(on: day, from: &state)
            },
            trackPendingLocalRemoval: { day, state in
                trackPendingLocalRemoval(on: day, in: &state)
            },
            removeCompletion: { day, state in
                removeCompletion(on: day, from: &state)
            },
            removeLogEntryLocally: { timestamp, state in
                removeLogEntry(at: timestamp, from: &state)
            },
            logsPreservingPendingLocalCompletions: { logs, state in
                logsPreservingPendingLocalCompletions(logs, in: &state)
            },
            upsertLocalLog: { date, state in
                upsertLocalLog(at: date, in: &state)
            },
            upsertConfirmedAssumedDoneLocalLog: { date, state in
                upsertLocalLog(at: date, isConfirmedAssumedDone: true, in: &state)
            },
            refreshTaskView: { state in
                refreshTaskView(&state)
            },
            updateDerivedState: { state in
                updateDerivedState(&state)
            },
            persistUndoCompletion: { taskID, completedDay in
                handleUndoCompletion(taskID: taskID, completedDay: completedDay)
            },
            persistRemoveLogEntry: { taskID, timestamp in
                handleRemoveLogEntry(taskID: taskID, timestamp: timestamp)
            },
            persistLogDuration: { taskID, logID, previousDuration, duration in
                handleUpdateLogDuration(
                    taskID: taskID,
                    logID: logID,
                    previousDurationMinutes: previousDuration,
                    durationMinutes: duration
                )
            },
            persistTaskDuration: { taskID, previousDuration, duration in
                handleUpdateTaskDuration(
                    taskID: taskID,
                    previousDurationMinutes: previousDuration,
                    durationMinutes: duration
                )
            },
            persistConfirmAssumedPastDays: { taskID, days in
                handleConfirmAssumedPastDays(taskID: taskID, days: days)
            }
        )
    }

    func editSaveRequestBuilder() -> TaskDetailEditSaveRequestBuilder {
        TaskDetailEditSaveRequestBuilder(
            now: { now },
            calendar: calendar,
            matrixPriority: { importance, urgency in
                matrixPriority(importance: importance, urgency: urgency)
            }
        )
    }

    func editAddDraftFlag(state: inout State) -> Effect<Action> {
        let flags = RoutineFlag.parseDraft(state.editFlagDraft)
        state.editFlagDraft = ""
        for flag in flags {
            _ = editToggleFlagSelection(flag, state: &state)
        }
        return .none
    }

    func editToggleFlagSelection(
        _ flag: String,
        state: inout State
    ) -> Effect<Action> {
        if RoutineFlag.contains(flag, in: state.editRoutineFlags) {
            state.editRoutineFlags = RoutineFlag.removing(flag, from: state.editRoutineFlags)
            state.editFlagSelectionValidationMessage = nil
            return .none
        }
        if RoutineFlagRules.contains(.autoAssumeDone, for: flag, in: state.flagRules) {
            if let reason = state.autoAssumeDoneUnavailableReason {
                state.editFlagSelectionValidationMessage =
                    "\(flag) was not added. \(reason) \(RoutineAssumedCompletion.flagRuleAvailabilitySummary)"
                return .none
            }
        }
        state.editRoutineFlags = RoutineFlag.appending(flag, to: state.editRoutineFlags)
        state.editFlagSelectionValidationMessage = nil
        return .none
    }

    func markManualFulfillmentTargetsDone(
        _ targetIDs: Set<UUID>,
        in state: inout State
    ) {
        guard !targetIDs.isEmpty else { return }
        for index in state.availableRelationshipTasks.indices
        where targetIDs.contains(state.availableRelationshipTasks[index].id) {
            state.availableRelationshipTasks[index].status = .doneToday
        }
        for index in state.editAvailableRelationshipTasks.indices
        where targetIDs.contains(state.editAvailableRelationshipTasks[index].id) {
            state.editAvailableRelationshipTasks[index].status = .doneToday
        }
    }
}
