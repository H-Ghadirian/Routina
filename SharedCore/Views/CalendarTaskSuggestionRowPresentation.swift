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
            return suggestion.eventStartDate.formatted(date: .abbreviated, time: .omitted)
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
}
