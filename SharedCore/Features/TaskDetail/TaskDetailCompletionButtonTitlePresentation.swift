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
        if shouldUseBulkConfirmAsPrimaryAction {
            return bulkConfirmAssumedDaysTitle
        }
        if task.isSoftIntervalRoutine && task.isOngoing {
            return "Finish ongoing"
        }
        if isSelectedDateAssumedDone {
            if calendar.isDateInToday(selectedDate) {
                return "Confirm done"
            }
            return "Confirm for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
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
        if task.isChecklistDriven && !calendar.isDateInToday(selectedDate) {
            return "Checklist routines can only be updated today"
        }
        if task.isChecklistDriven {
            let dueItems = task.dueChecklistItems(referenceDate: referenceDate)
            if dueItems.isEmpty {
                return "No due items right now"
            }
            if dueItems.count == 1, let title = dueItems.first?.title {
                return "Buy: \(title)"
            }
            return "Buy \(dueItems.count) due items"
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

    private var exactTimedOccurrenceTitle: String {
        if let completionTargetDate {
            if calendar.isDateInToday(completionTargetDate) {
                return "Done at \(completionTargetDate.formatted(date: .omitted, time: .shortened))"
            }
            return "Done for \(completionTargetDate.formatted(date: .abbreviated, time: .shortened))"
        }

        if calendar.isDateInToday(selectedDate) {
            let nextDue = RoutineDateMath.dueDate(for: task, referenceDate: referenceDate)
            return "Available \(nextDue.formatted(date: .abbreviated, time: .shortened))"
        }

        return "No occurrence on \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
    }
}
