import Foundation

struct CalendarTaskSuggestionStatusPresentation: Equatable {
    enum Tint: Equatable {
        case success
        case secondary
    }

    let title: String
    let systemImage: String
    let tint: Tint
}

enum CalendarTaskSuggestionRowPresentation {
    static func formattedEventDate(for suggestion: CalendarTaskSuggestion) -> String {
        if suggestion.isAllDay {
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: suggestion.eventStartDate)
            let endDay = normalizedAllDayEndDate(
                startDate: suggestion.eventStartDate,
                endDate: suggestion.eventEndDate,
                calendar: calendar
            )
            let lastVisibleDay = calendar.date(byAdding: .day, value: -1, to: endDay) ?? startDay
            if calendar.isDate(startDay, inSameDayAs: lastVisibleDay) {
                return startDay.formatted(date: .abbreviated, time: .omitted)
            }
            return "\(startDay.formatted(date: .abbreviated, time: .omitted)) - \(lastVisibleDay.formatted(date: .abbreviated, time: .omitted))"
        }
        return suggestion.eventStartDate.formatted(date: .abbreviated, time: .shortened)
    }

    static func status(
        for reviewState: CalendarTaskSuggestion.ReviewState
    ) -> CalendarTaskSuggestionStatusPresentation? {
        switch reviewState {
        case .pending:
            return nil
        case .added:
            return CalendarTaskSuggestionStatusPresentation(
                title: "Added",
                systemImage: "checkmark.circle.fill",
                tint: .success
            )
        case .skipped:
            return CalendarTaskSuggestionStatusPresentation(
                title: "Skipped",
                systemImage: "minus.circle",
                tint: .secondary
            )
        case .duplicate:
            return CalendarTaskSuggestionStatusPresentation(
                title: "Already added",
                systemImage: "checkmark.circle",
                tint: .secondary
            )
        }
    }

    static func isEditable(_ reviewState: CalendarTaskSuggestion.ReviewState) -> Bool {
        reviewState == .pending
    }

    static func canAdd(_ suggestion: CalendarTaskSuggestion) -> Bool {
        isEditable(suggestion.reviewState)
            && RoutineTask.trimmedName(suggestion.taskTitle) != nil
    }

    private static func normalizedAllDayEndDate(
        startDate: Date,
        endDate: Date,
        calendar: Calendar
    ) -> Date {
        let startDay = calendar.startOfDay(for: startDate)
        guard endDate > startDate else {
            return calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        }

        let endDay = calendar.startOfDay(for: endDate)
        if endDay <= startDay {
            return calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        }

        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: endDate)
        let endsAtStartOfDay = (components.hour ?? 0) == 0
            && (components.minute ?? 0) == 0
            && (components.second ?? 0) == 0
            && (components.nanosecond ?? 0) == 0
        if endsAtStartOfDay {
            return endDay
        }

        return calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
    }
}
