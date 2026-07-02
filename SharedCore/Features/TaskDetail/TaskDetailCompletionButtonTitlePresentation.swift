import Foundation

struct TaskDetailCompletionButtonTitlePresentation {
    let task: RoutineTask
    let selectedDate: Date
    let isSelectedDateTerminal: Bool
    let isSelectedDateInFuture: Bool
    let shouldUseBulkConfirmAsPrimaryAction: Bool
    let bulkConfirmAssumedDaysTitle: String
    let isSelectedDateAssumedDone: Bool
    let completionTargetDate: Date?
    var hasUnresolvedMissedExactTimedOccurrence: Bool? = nil
    var referenceDate: Date = Date()
    var calendar: Calendar = .current

    var title: String {
        if !task.isChecklistDriven && isSelectedDateTerminal {
            return "Undo"
        }
        if task.isCanceledOneOff {
            return "Select the canceled date to undo"
        }
        if task.isCompletedOneOff {
            return "Select the completion date to undo"
        }
        if task.isArchived() {
            return "Resume the routine to mark dates done"
        }
        if task.usesOngoingLifecycle && task.isOngoing {
            if task.isMultiDayRoutine, isSelectedDateBeforeOngoingStart {
                return "Select a stop date after start"
            }
            return task.isMultiDayRoutine ? "Stop" : "Finish ongoing"
        }
        if task.isMultiDayRoutine {
            return "Start"
        }
        if shouldUseBulkConfirmAsPrimaryAction {
            return bulkConfirmAssumedDaysTitle
        }
        if isSelectedDateAssumedDone {
            if calendar.isDateInToday(selectedDate) {
                return "Confirm done"
            }
            return "Confirm for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
        }
        if task.blocksManualCompletionForIncompleteChecklist {
            return "Complete checklist items first"
        }
        if task.isOneOffTask {
            if calendar.isDateInToday(selectedDate) {
                return "Done"
            }
            return "Done for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
        }
        if task.isChecklistCompletionRoutine && !calendar.isDateInToday(selectedDate) {
            return "Checklist progress can only be updated today"
        }
        if task.isChecklistCompletionRoutine {
            return "Complete checklist items below"
        }
        if task.isChecklistDriven {
            if isSelectedDateInFuture {
                return "Future dates can't be marked done"
            }
            let dueItems = task.dueChecklistItems(referenceDate: selectedDate, calendar: calendar)
            if dueItems.isEmpty {
                return calendar.isDateInToday(selectedDate) ? "No due items right now" : "No due items on selected day"
            }
            if dueItems.count == 1, let title = dueItems.first?.title {
                return "Done: \(title)"
            }
            return "Done \(dueItems.count) due items"
        }
        if task.hasSequentialSteps && !calendar.isDateInToday(selectedDate) {
            return "Step routines can only be progressed today"
        }
        if RoutineDateMath.usesExactTimedOccurrenceTracking(for: task) {
            return exactTimedOccurrenceTitle
        }
        if isSelectedDateInFuture {
            return "Future dates can't be marked done"
        }
        if let nextStepTitle = task.nextStepTitle {
            return "Complete: \(nextStepTitle)"
        }
        if calendar.isDateInToday(selectedDate) {
            return "Done"
        }
        return "Done for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private var isSelectedDateBeforeOngoingStart: Bool {
        guard let ongoingSince = task.ongoingSince else { return false }
        return calendar.startOfDay(for: selectedDate) < calendar.startOfDay(for: ongoingSince)
    }

    private var exactTimedOccurrenceTitle: String {
        if let completionTargetDate {
            if calendar.isDate(completionTargetDate, inSameDayAs: referenceDate) {
                return "Done at \(completionTargetDate.formatted(date: .omitted, time: .shortened))"
            }
            return "Done for \(completionTargetDate.formatted(date: .abbreviated, time: .shortened))"
        }

        let hasUnresolvedMissed = hasUnresolvedMissedExactTimedOccurrence
            ?? (RoutineDateMath.missedExactTimedOccurrenceDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) != nil)
        if hasUnresolvedMissed, calendar.isDate(selectedDate, inSameDayAs: referenceDate) {
            return "Missed"
        }

        if calendar.isDate(selectedDate, inSameDayAs: referenceDate) {
            let nextDue = RoutineDateMath.upcomingDueDate(for: task, referenceDate: referenceDate, calendar: calendar)
            return "Available \(nextDue.formatted(date: .abbreviated, time: .shortened))"
        }

        return "No occurrence on \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
    }
}
