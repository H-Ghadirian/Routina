import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct CalendarTaskImportFeature {
    @ObservableState
    struct State: Equatable {
        var addedSuggestionIDs: Set<String> = []
    }

    enum Action: Equatable {
        case addTaskRequested(CalendarTaskSuggestion)
        case addTaskSucceeded(String)
        case addTaskFailed(String)
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.modelContext) var modelContext

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .addTaskRequested(suggestion):
                guard suggestion.reviewState == .pending,
                      let trimmedTitle = RoutineTask.trimmedName(suggestion.taskTitle),
                      !state.addedSuggestionIDs.contains(suggestion.id) else {
                    return .none
                }

                let notes = CalendarTaskImportSupport.notes(for: suggestion, calendar: calendar)
                return .run { @MainActor send in
                    let context = modelContext()
                    let task = RoutineTask(
                        name: trimmedTitle,
                        emoji: CalendarTaskImportSupport.defaultTaskEmoji,
                        notes: notes,
                        deadline: suggestion.deadline,
                        isAllDay: suggestion.isAllDay,
                        priority: .none,
                        importance: .level2,
                        urgency: .level2,
                        tags: ["Calendar"],
                        scheduleMode: .oneOff,
                        interval: 1,
                        recurrenceRule: .interval(days: 1),
                        todoStateRawValue: TodoState.ready.rawValue
                    )
                    context.insert(task)

                    do {
                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                        send(.addTaskSucceeded(suggestion.id))
                    } catch {
                        context.delete(task)
                        send(.addTaskFailed(suggestion.id))
                    }
                }

            case let .addTaskSucceeded(suggestionID):
                state.addedSuggestionIDs.insert(suggestionID)
                return .none

            case .addTaskFailed:
                return .none
            }
        }
    }
}
