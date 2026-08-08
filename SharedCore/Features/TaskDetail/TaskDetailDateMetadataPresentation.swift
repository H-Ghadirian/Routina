import Foundation

enum TaskDetailDateMetadataPresentation {
    static func dueDateMetadataText(
        dueDate: Date?,
        isOneOffTask: Bool,
        usesExplicitTimeOfDay: Bool,
        calendar: Calendar = .current
    ) -> String? {
        guard let dueDate else {
            return nil
        }
        if isOneOffTask || usesExplicitTimeOfDay {
            return dueDate.formatted(date: .abbreviated, time: .shortened)
        }
        guard !calendar.isDateInToday(dueDate) else { return nil }
        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    static func reminderMetadataText(reminderAt: Date?) -> String? {
        guard let reminderAt else { return nil }
        return reminderAt.formatted(date: .abbreviated, time: .shortened)
    }

    static func scheduledTimeBlockMetadataText(
        task: RoutineTask,
        calendar: Calendar = .current
    ) -> String? {
        guard task.isOneOffTask,
              !task.isAllDay,
              task.availabilityEndDate == nil,
              task.recurrenceTimeRangeRole == .scheduledBlock,
              let availabilityStartDate = task.availabilityStartDate,
              let timeRange = task.recurrenceRule.timeRange
        else {
            return nil
        }

        let startsAt = timeRange.startDate(on: availabilityStartDate, calendar: calendar)
        let endsAt = timeRange.endDate(on: availabilityStartDate, calendar: calendar)
        let dateText = startsAt.formatted(date: .abbreviated, time: .omitted)
        let startTimeText = startsAt.formatted(date: .omitted, time: .shortened)
        let endTimeText = endsAt.formatted(date: .omitted, time: .shortened)
        return "\(dateText) · \(startTimeText)–\(endTimeText)"
    }

    static func shouldShowSelectedDateMetadata(
        selectedDate: Date,
        task: RoutineTask,
        calendar: Calendar = .current
    ) -> Bool {
        !calendar.isDateInToday(selectedDate)
            && !task.isCompletedOneOff
            && !task.isCanceledOneOff
    }

    static func selectedDateMetadataText(
        selectedDate: Date,
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        }
        return selectedDate.formatted(date: .abbreviated, time: .omitted)
    }

    static func cancelTodoButtonTitle(
        selectedDate: Date,
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDateInToday(selectedDate) {
            return "Cancel todo"
        }
        return "Cancel for \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
    }
}
