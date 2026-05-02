import Foundation

struct TodoStateTimingStateTotal: Equatable, Identifiable {
    var state: TodoState
    var days: Int

    var id: TodoState { state }
}

struct TodoStateTimingSummary: Equatable {
    var createdAt: Date
    var completedAt: Date?
    var completedLeadDays: Int?
    var currentState: TodoState?
    var currentStateStartedAt: Date?
    var currentStateElapsedDays: Int?
    var stateTotals: [TodoStateTimingStateTotal]

    func totalDays(for state: TodoState) -> Int {
        stateTotals.first(where: { $0.state == state })?.days ?? 0
    }
}

enum TodoStateTiming {
    static let trackedStates: [TodoState] = [.ready, .inProgress, .blocked, .paused]

    private struct StateEvent: Equatable {
        var timestamp: Date
        var previousState: TodoState?
        var newState: TodoState
    }

    static func summary(
        for task: RoutineTask,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TodoStateTimingSummary? {
        guard task.isOneOffTask else { return nil }

        let changeEntries = task.changeLogEntries
        let createdAt = resolvedCreatedAt(
            for: task,
            changeEntries: changeEntries,
            referenceDate: referenceDate
        )
        let completedAt = task.isCompletedOneOff ? task.lastDone : nil
        let terminalDate = minDate(task.canceledAt ?? completedAt ?? referenceDate, referenceDate)
        let currentState = completedAt == nil && task.canceledAt == nil ? task.todoState : nil
        let events = stateEvents(
            for: task,
            changeEntries: changeEntries,
            createdAt: createdAt,
            terminalDate: terminalDate
        )

        let initialState = resolvedInitialState(
            task: task,
            events: events,
            createdAt: createdAt,
            currentState: currentState
        )
        var activeState = initialState
        var activeStateStartedAt = createdAt
        var totals = Dictionary(uniqueKeysWithValues: trackedStates.map { ($0, 0) })

        for event in events where event.timestamp <= terminalDate {
            let eventDate = maxDate(event.timestamp, createdAt)
            guard eventDate >= activeStateStartedAt else {
                activeState = event.newState
                activeStateStartedAt = eventDate
                continue
            }

            addElapsedDays(
                from: activeStateStartedAt,
                to: eventDate,
                state: activeState,
                calendar: calendar,
                totals: &totals
            )
            activeState = event.newState
            activeStateStartedAt = eventDate

            if event.newState == .done {
                break
            }
        }

        if completedAt == nil {
            addElapsedDays(
                from: activeStateStartedAt,
                to: terminalDate,
                state: activeState,
                calendar: calendar,
                totals: &totals
            )
        } else if let completedAt {
            addElapsedDays(
                from: activeStateStartedAt,
                to: minDate(completedAt, terminalDate),
                state: activeState,
                calendar: calendar,
                totals: &totals
            )
        }

        let currentStateStartedAt = currentState.map { state in
            resolvedCurrentStateStartDate(
                state,
                fallback: activeState == state ? activeStateStartedAt : createdAt,
                events: events,
                referenceDate: referenceDate
            )
        }
        let currentStateElapsedDays = currentStateStartedAt.map {
            elapsedDays(from: $0, to: referenceDate, calendar: calendar)
        }

        return TodoStateTimingSummary(
            createdAt: createdAt,
            completedAt: completedAt,
            completedLeadDays: completedAt.map { elapsedDays(from: createdAt, to: $0, calendar: calendar) },
            currentState: currentState,
            currentStateStartedAt: currentStateStartedAt,
            currentStateElapsedDays: currentStateElapsedDays,
            stateTotals: trackedStates.map {
                TodoStateTimingStateTotal(state: $0, days: max(totals[$0, default: 0], 0))
            }
        )
    }

    static func elapsedDays(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: maxDate(startDate, endDate))
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    static func state(from value: String?) -> TodoState? {
        guard let value else { return nil }
        let candidate = normalizedStateToken(value)
        return TodoState.allCases.first { state in
            normalizedStateToken(state.rawValue) == candidate
                || normalizedStateToken(state.displayTitle) == candidate
        }
    }

    private static func resolvedCreatedAt(
        for task: RoutineTask,
        changeEntries: [RoutineTaskChangeLogEntry],
        referenceDate: Date
    ) -> Date {
        if let createdAt = task.createdAt {
            return createdAt
        }
        if let createdAt = changeEntries
            .filter({ $0.kind == .created })
            .map(\.timestamp)
            .min() {
            return createdAt
        }
        return changeEntries.map(\.timestamp).min()
            ?? task.lastDone
            ?? task.canceledAt
            ?? referenceDate
    }

    private static func stateEvents(
        for task: RoutineTask,
        changeEntries: [RoutineTaskChangeLogEntry],
        createdAt: Date,
        terminalDate: Date
    ) -> [StateEvent] {
        var events = changeEntries
            .filter { $0.kind == .stateChanged }
            .compactMap { entry -> StateEvent? in
                guard let newState = state(from: entry.newValue) else { return nil }
                return StateEvent(
                    timestamp: entry.timestamp,
                    previousState: state(from: entry.previousValue),
                    newState: newState
                )
            }
            .filter { $0.timestamp >= createdAt && $0.timestamp <= terminalDate }

        if let pausedAt = task.pausedAt,
           pausedAt >= createdAt,
           pausedAt <= terminalDate,
           !events.contains(where: { $0.newState == .paused && $0.timestamp == pausedAt }) {
            events.append(StateEvent(timestamp: pausedAt, previousState: nil, newState: .paused))
        }

        if let completedAt = task.lastDone,
           task.isCompletedOneOff,
           completedAt >= createdAt,
           completedAt <= terminalDate,
           !events.contains(where: { $0.newState == .done && $0.timestamp == completedAt }) {
            events.append(StateEvent(timestamp: completedAt, previousState: nil, newState: .done))
        }

        return events.sorted {
            if $0.timestamp == $1.timestamp {
                return $0.newState.rawValue < $1.newState.rawValue
            }
            return $0.timestamp < $1.timestamp
        }
    }

    private static func resolvedInitialState(
        task: RoutineTask,
        events: [StateEvent],
        createdAt: Date,
        currentState: TodoState?
    ) -> TodoState {
        if let firstEvent = events.first,
           firstEvent.timestamp > createdAt,
           let previousState = firstEvent.previousState,
           trackedStates.contains(previousState) {
            return previousState
        }
        if events.isEmpty {
            return currentState
                ?? state(from: task.todoStateRawValue)
                ?? .ready
        }
        return state(from: task.todoStateRawValue)
            ?? currentState
            ?? events.first?.previousState
            ?? .ready
    }

    private static func resolvedCurrentStateStartDate(
        _ state: TodoState,
        fallback: Date,
        events: [StateEvent],
        referenceDate: Date
    ) -> Date {
        events
            .filter { $0.timestamp <= referenceDate && $0.newState == state }
            .last?
            .timestamp
            ?? fallback
    }

    private static func addElapsedDays(
        from startDate: Date,
        to endDate: Date,
        state: TodoState,
        calendar: Calendar,
        totals: inout [TodoState: Int]
    ) {
        guard trackedStates.contains(state) else { return }
        totals[state, default: 0] += elapsedDays(
            from: startDate,
            to: endDate,
            calendar: calendar
        )
    }

    private static func normalizedStateToken(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func minDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs < rhs ? lhs : rhs
    }

    private static func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }
}
