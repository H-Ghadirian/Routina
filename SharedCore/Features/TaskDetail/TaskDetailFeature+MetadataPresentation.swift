import Foundation

extension TaskDetailFeature.State {
    /// Due date resolved from the task (one-off deadline or next recurrence).
    var resolvedDueDate: Date? {
        if task.isSoftIntervalRoutine {
            return nil
        }
        if task.isOneOffTask {
            return task.deadline
        }
        guard task.usesEffectiveRoutineCadence else {
            return nil
        }
        let referenceDate = Date()
        if isChecklistDrivenFromStoredItems {
            return
                detailChecklistItems
                .map {
                    RoutineDateMath.dueDate(
                        for: $0,
                        referenceDate: referenceDate,
                        calendar: .current
                    )
                }
                .min()
        }
        return RoutineDateMath.upcomingDueDate(for: task, referenceDate: referenceDate)
    }

    /// Soft routines use a threshold date instead of a hard overdue date.
    var resolvedSoftDueDate: Date? {
        guard task.surfacesSoftIntervalNudges else { return nil }
        return RoutineDateMath.softIntervalThresholdDate(for: task)
    }

    var dueDateMetadataText: String? {
        TaskDetailDateMetadataPresentation.dueDateMetadataText(
            dueDate: resolvedDueDate,
            isOneOffTask: task.isOneOffTask,
            usesExplicitTimeOfDay: task.recurrenceRule.usesTimeConstraint
        )
    }

    var reminderMetadataText: String? {
        guard task.isOneOffTask else { return nil }
        return TaskDetailDateMetadataPresentation.reminderMetadataText(reminderAt: task.reminderAt)
    }

    var scheduledTimeBlockMetadataText: String? {
        TaskDetailDateMetadataPresentation.scheduledTimeBlockMetadataText(task: task)
    }

    var notificationDisabledWarningText: String? {
        TaskDetailNotificationWarningPresentation.warningText(
            hasLoadedNotificationStatus: hasLoadedNotificationStatus,
            expectsClockTimeNotification: expectsClockTimeNotification,
            appNotificationsEnabled: appNotificationsEnabled,
            systemNotificationsAuthorized: systemNotificationsAuthorized
        )
    }

    var notificationDisabledWarningActionTitle: String? {
        TaskDetailNotificationWarningPresentation.actionTitle(
            warningText: notificationDisabledWarningText,
            appNotificationsEnabled: appNotificationsEnabled
        )
    }

    var expectsClockTimeNotification: Bool {
        if task.isOneOffTask, task.reminderAt != nil {
            return NotificationCoordinator.shouldScheduleNotification(for: task, referenceDate: Date())
        }
        if task.isOneOffTask {
            return NotificationCoordinator.shouldScheduleNotification(for: task, referenceDate: Date())
        }
        guard task.recurrenceRule.usesTimeConstraint else { return false }
        return NotificationCoordinator.shouldScheduleNotification(for: task, referenceDate: Date())
    }

    var shouldShowSelectedDateMetadata: Bool {
        TaskDetailDateMetadataPresentation.shouldShowSelectedDateMetadata(
            selectedDate: resolvedSelectedDate,
            task: task
        )
    }

    var selectedDateMetadataText: String {
        TaskDetailDateMetadataPresentation.selectedDateMetadataText(selectedDate: resolvedSelectedDate)
    }

    var cancelTodoButtonTitle: String {
        TaskDetailDateMetadataPresentation.cancelTodoButtonTitle(selectedDate: resolvedSelectedDate)
    }

    var isCancelTodoButtonDisabled: Bool {
        task.isArchived() || task.isCompletedOneOff || task.isCanceledOneOff || isSelectedDateInFuture
    }

    var routineEmoji: String {
        CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "✨"
    }

    var frequencyText: String {
        if task.isOneOffTask {
            return "One-time task"
        }
        if !task.cadenceEnabled {
            return "None"
        }
        if isChecklistDrivenFromStoredItems {
            return "Checklist-driven"
        }
        return task.recurrenceRule.displayText()
    }

    var stepProgressText: String {
        guard task.hasSequentialSteps else { return "" }
        if task.isInProgress {
            return "Step \(task.completedSteps + 1) of \(task.totalSteps)"
        }
        return "\(task.totalSteps) sequential \(task.totalSteps == 1 ? "step" : "steps")"
    }

    var checklistProgressText: String {
        if isSelectedChecklistCompletionDateDone {
            if Calendar.current.isDateInToday(resolvedSelectedDate) {
                return "All items completed today"
            }
            return "All items completed on selected day"
        }
        let completed = completedChecklistItemCount(referenceDate: resolvedSelectedDate)
        let total = max(totalChecklistItemCount, 1)
        return "\(completed) of \(total) items completed"
    }

    var isSelectedChecklistCompletionDateDone: Bool {
        isChecklistCompletionFromStoredItems && isSelectedDateDone
    }

    var completedLogCountText: String {
        completedLogCount == 1 ? "1 completion" : "\(completedLogCount) completions"
    }

    var canceledLogCountText: String {
        canceledLogCount == 1 ? "1 cancel" : "\(canceledLogCount) cancels"
    }

    func priorityMetadataText(priorityLabel: String) -> String {
        "\(priorityLabel) • \(task.importance.title) importance • \(task.urgency.title) urgency"
    }
}
