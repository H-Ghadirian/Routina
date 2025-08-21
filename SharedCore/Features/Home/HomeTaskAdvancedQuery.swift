import Foundation

struct HomeTaskAdvancedQuery<Display: HomeTaskListDisplay> {
    private let clauses: [[Token]]

    init(_ query: String) {
        clauses = Self.parse(query)
    }

    var isEmpty: Bool {
        clauses.isEmpty
    }

    func matches(_ task: Display, metrics: HomeTaskListMetrics<Display>) -> Bool {
        guard !clauses.isEmpty else { return true }
        return clauses.contains { tokens in
            tokens.allSatisfy { token in
                let isMatch = matches(token: token, task: task, metrics: metrics)
                return token.isNegated ? !isMatch : isMatch
            }
        }
    }

    private func matches(
        token: Token,
        task: Display,
        metrics: HomeTaskListMetrics<Display>
    ) -> Bool {
        let value = token.value
        switch token.field {
        case nil:
            return matchesAnyText(value, task: task)
        case "name", "title":
            return task.name.normalizedQueryText.contains(value)
        case "note", "notes":
            return task.notes?.normalizedQueryText.contains(value) ?? false
        case "tag", "tags":
            return task.tags.contains { $0.normalizedQueryText.contains(value) }
        case "goal", "goals":
            return task.goalTitles.contains { $0.normalizedQueryText.contains(value) }
        case "place", "location":
            return task.placeName?.normalizedQueryText.contains(value) ?? false
        case "type", "kind":
            return matchesTaskType(value, task: task)
        case "is", "status", "state":
            return matchesState(value, task: task)
        case "priority":
            return matchesOrderedValue(
                token,
                currentSortOrder: task.priority.sortOrder,
                currentTitle: task.priority.title,
                candidates: RoutineTaskPriority.allCases.map { ($0.title, $0.sortOrder) }
            )
        case "importance":
            return matchesOrderedValue(
                token,
                currentSortOrder: task.importance.sortOrder,
                currentTitle: task.importance.title,
                candidates: RoutineTaskImportance.allCases.map { ($0.title, $0.sortOrder) }
            )
        case "urgency":
            return matchesOrderedValue(
                token,
                currentSortOrder: task.urgency.sortOrder,
                currentTitle: task.urgency.title,
                candidates: RoutineTaskUrgency.allCases.map { ($0.title, $0.sortOrder) }
            )
        case "pressure":
            return matchesOrderedValue(
                token,
                currentSortOrder: task.pressure.sortOrder,
                currentTitle: task.pressure.title,
                candidates: RoutineTaskPressure.allCases.map { ($0.title, $0.sortOrder) }
            )
        case "due":
            return matchesDue(value, task: task, metrics: metrics)
        default:
            return false
        }
    }

    private func matchesAnyText(_ value: String, task: Display) -> Bool {
        task.name.normalizedQueryText.contains(value)
            || task.emoji.normalizedQueryText.contains(value)
            || (task.notes?.normalizedQueryText.contains(value) ?? false)
            || (task.placeName?.normalizedQueryText.contains(value) ?? false)
            || task.tags.contains { $0.normalizedQueryText.contains(value) }
            || task.goalTitles.contains { $0.normalizedQueryText.contains(value) }
    }

    private func matchesTaskType(_ value: String, task: Display) -> Bool {
        if ["todo", "todos", "task", "oneoff", "one-off"].contains(value) {
            return task.isOneOffTask
        }
        if ["routine", "routines", "recurring"].contains(value) {
            return !task.isOneOffTask
        }
        return false
    }

    private func matchesState(_ value: String, task: Display) -> Bool {
        switch value {
        case "done", "completed":
            return task.isDoneToday || task.isCompletedOneOff || task.todoState == .done
        case "today":
            return task.isDoneToday
        case "canceled", "cancelled":
            return task.isCanceledOneOff
        case "paused":
            return task.isPaused || task.todoState == .paused
        case "pinned":
            return task.isPinned
        case "progress", "inprogress", "in-progress":
            return task.isInProgress || task.todoState == .inProgress
        case "ready":
            return task.todoState == .ready
        case "blocked":
            return task.todoState == .blocked
        case "todo", "routine":
            return matchesTaskType(value, task: task)
        default:
            return task.todoState?.displayTitle.normalizedQueryText.contains(value) ?? false
        }
    }

    private func matchesDue(
        _ value: String,
        task: Display,
        metrics: HomeTaskListMetrics<Display>
    ) -> Bool {
        let daysUntilDue = metrics.dueInDays(for: task)
        switch value {
        case "overdue", "late":
            return daysUntilDue < 0
        case "today", "now":
            return daysUntilDue == 0
        case "soon", "due":
            return daysUntilDue <= 3
        case "future", "later":
            return daysUntilDue > 3
        default:
            return false
        }
    }

    private func matches(_ value: String, title: String) -> Bool {
        title.normalizedQueryText == value || title.normalizedQueryText.contains(value)
    }

    private func matchesLevel(_ value: String, title: String, sortOrder: Int) -> Bool {
        matches(value, title: title) || value == "l\(sortOrder)" || value == "level\(sortOrder)"
    }

    private func matchesOrderedValue(
        _ token: Token,
        currentSortOrder: Int,
        currentTitle: String,
        candidates: [(title: String, sortOrder: Int)]
    ) -> Bool {
        guard let comparison = token.comparison else {
            return matchesLevel(token.value, title: currentTitle, sortOrder: currentSortOrder)
        }
        guard let targetSortOrder = sortOrder(for: token.value, candidates: candidates) else {
            return false
        }

        switch comparison {
        case .greaterThan:
            return currentSortOrder > targetSortOrder
        case .greaterThanOrEqual:
            return currentSortOrder >= targetSortOrder
        case .lessThan:
            return currentSortOrder < targetSortOrder
        case .lessThanOrEqual:
            return currentSortOrder <= targetSortOrder
        }
    }

    private func sortOrder(
        for value: String,
        candidates: [(title: String, sortOrder: Int)]
    ) -> Int? {
        if let level = Self.levelSortOrder(from: value) {
            return level
        }
        return candidates.first { candidate in
            matches(value, title: candidate.title)
        }?.sortOrder
    }

    private static func parse(_ query: String) -> [[Token]] {
        split(query).reduce(into: [[]]) { clauses, rawToken in
            let normalizedToken = rawToken.normalizedQueryText
            if normalizedToken == "or" {
                if clauses.last?.isEmpty == false {
                    clauses.append([])
                }
                return
            }
            if normalizedToken == "and" {
                return
            }
            guard let token = parseToken(rawToken) else { return }
            clauses[clauses.count - 1].append(token)
        }
        .filter { !$0.isEmpty }
    }

    private static func parseToken(_ rawToken: String) -> Token? {
            var rawToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawToken.isEmpty else { return nil }

            let isNegated = rawToken.hasPrefix("-")
            if isNegated { rawToken.removeFirst() }
            guard !rawToken.isEmpty else { return nil }

            let parts = rawToken.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                let field = String(parts[0]).normalizedQueryText
                let parsedValue = parsedComparisonValue(String(parts[1]).normalizedQueryText)
                guard !field.isEmpty, !parsedValue.value.isEmpty else { return nil }
                return Token(
                    field: field,
                    value: parsedValue.value,
                    comparison: parsedValue.comparison,
                    isNegated: isNegated
                )
            }

            let value = rawToken.normalizedQueryText
            guard !value.isEmpty else { return nil }
            return Token(field: nil, value: value, comparison: nil, isNegated: isNegated)
    }

    private static func parsedComparisonValue(_ value: String) -> (comparison: Comparison?, value: String) {
        for comparison in Comparison.allCases {
            if value.hasPrefix(comparison.rawValue) {
                let comparedValue = String(value.dropFirst(comparison.rawValue.count))
                return (comparison, comparedValue)
            }
        }
        return (nil, value)
    }

    private static func levelSortOrder(from value: String) -> Int? {
        if value.hasPrefix("level") {
            return Int(value.dropFirst("level".count))
        }
        if value.hasPrefix("l") {
            return Int(value.dropFirst())
        }
        return nil
    }

    private static func split(_ query: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var isQuoted = false

        for character in query {
            if character == "\"" {
                isQuoted.toggle()
                continue
            }
            if character.isWhitespace && !isQuoted {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private struct Token: Equatable {
        var field: String?
        var value: String
        var comparison: Comparison?
        var isNegated: Bool
    }

    private enum Comparison: String, CaseIterable {
        case greaterThanOrEqual = ">="
        case lessThanOrEqual = "<="
        case greaterThan = ">"
        case lessThan = "<"
    }
}

private extension String {
    var normalizedQueryText: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
