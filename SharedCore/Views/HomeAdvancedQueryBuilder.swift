import SwiftUI

struct HomeAdvancedQueryBuilder: View {
    @Binding var query: String
    var usesFlowLayout: Bool = false
    var options = HomeAdvancedQueryOptions()

    @FocusState private var isFocused: Bool

    private var state: HomeAdvancedQueryInputState {
        HomeAdvancedQueryInputState(query: query, options: options)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            inlineQueryInput

            suggestionRow
        }
    }

    private var inlineQueryInput: some View {
        HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(Array(state.tokens.enumerated()), id: \.offset) { index, token in
                committedTokenChip(token, at: index)
            }

            queryDraftInput
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.24), lineWidth: isFocused ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture { isFocused = true }
    }

    private var queryDraftInput: some View {
        ZStack(alignment: .leading) {
            if isFocused, let ghostSuffix = state.primaryGhostSuffix, !ghostSuffix.isEmpty {
                HStack(spacing: 0) {
                    Text(state.draft)
                        .foregroundStyle(.clear)
                    Text(ghostSuffix)
                        .foregroundStyle(.tertiary)
                }
                .font(.body)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            TextField(state.tokens.isEmpty ? "tag:work -is:done type:todo" : "", text: draftBinding)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .advancedQueryInputTraits()
                .frame(minWidth: state.draft.isEmpty ? 140 : 40)
                .onSubmit { acceptPrimarySuggestionOrCommitDraft() }
                .onKeyPress(SwiftUI.KeyEquivalent.tab) {
                    acceptPrimarySuggestionOrCommitDraft()
                    return SwiftUI.KeyPress.Result.handled
                }
                .onKeyPress(SwiftUI.KeyEquivalent.space) {
                    commitDraftFromSpace()
                    return SwiftUI.KeyPress.Result.handled
                }
                .onKeyPress(SwiftUI.KeyEquivalent.delete) {
                    if state.draft.isEmpty, !state.tokens.isEmpty {
                        query = state.removingToken(at: state.tokens.count - 1)
                        return SwiftUI.KeyPress.Result.handled
                    }
                    return SwiftUI.KeyPress.Result.ignored
                }
        }
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { state.draft },
            set: { newValue in
                if newValue.contains(where: \.isWhitespace) {
                    let draft = newValue.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
                    query = HomeAdvancedQueryInputState(query: query, options: options).committingDraft(draft)
                } else {
                    query = HomeAdvancedQueryInputState(query: query, options: options).replacingDraftOrCommittingExactAtomicToken(with: newValue)
                }
            }
        )
    }

    @ViewBuilder
    private var suggestionRow: some View {
        let suggestions = state.suggestions
        if usesFlowLayout {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(suggestions) { suggestionButton($0) }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { suggestionButton($0) }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func committedTokenChip(_ token: String, at index: Int) -> some View {
        Button {
            query = state.removingToken(at: index)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)

                ForEach(state.displayParts(for: token)) { part in
                    Text(part.title)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(part.kind.color.opacity(0.18))
                        )
                        .foregroundStyle(part.kind.color)
                }
            }
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.plain)
        .controlSize(.small)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(token.isAdvancedQueryOperator ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
        )
        .help("Remove \(token)")
    }

    private func suggestionButton(_ suggestion: HomeAdvancedQuerySuggestion) -> some View {
        Button {
            query = state.accepting(suggestion)
            isFocused = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.token)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(suggestion.kind.color)
                Text(suggestion.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 30, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(suggestion.description)
    }

    private func acceptPrimarySuggestionOrCommitDraft() {
        if let suggestion = state.primarySuggestion {
            query = state.accepting(suggestion)
        } else {
            query = state.committingDraft()
        }
    }

    private func commitDraftFromSpace() {
        query = state.draft.isEmpty ? state.query : state.committingDraft()
    }
}

struct HomeAdvancedQueryInputState: Equatable {
    var query: String
    var options = HomeAdvancedQueryOptions()

    var tokens: [String] {
        split(query).committedTokens
    }

    var draft: String {
        split(query).draft
    }

    var suggestions: [HomeAdvancedQuerySuggestion] {
        let rawDraft = draft
        let normalizedDraft = rawDraft.normalizedAdvancedQueryToken
        let candidates = suggestionCandidates

        guard !normalizedDraft.isEmpty else {
            return candidates
        }

        let exactPrefixMatches = candidates.filter {
            $0.matchesPrefix(rawDraft)
        }
        if !exactPrefixMatches.isEmpty {
            return Array(exactPrefixMatches.prefix(candidates.isContextualValueList ? candidates.count : 8))
        }

        let fieldScopedMatches = candidates.filter {
            $0.searchText.contains(normalizedDraft)
        }
        return Array(fieldScopedMatches.prefix(8))
    }

    var primarySuggestion: HomeAdvancedQuerySuggestion? {
        suggestions.first { suggestion in
            let normalizedDraft = draft.normalizedAdvancedQueryToken
            return !normalizedDraft.isEmpty
                && suggestion.insertionToken.normalizedAdvancedQueryToken.hasPrefix(normalizedDraft)
                && suggestion.insertionToken.normalizedAdvancedQueryToken != normalizedDraft
        }
    }

    var primaryGhostSuffix: String? {
        primarySuggestion?.ghostSuffix(for: draft)
    }

    func accepting(_ suggestion: HomeAdvancedQuerySuggestion) -> String {
        replacingDraft(with: suggestion.insertionToken, addsTrailingSpace: suggestion.isAtomic)
    }

    func committingDraft() -> String {
        committingDraft(draft)
    }

    func committingDraft(_ draft: String) -> String {
        let state = replacingDraftForEditing(with: draft)
        let draftState = HomeAdvancedQueryInputState(query: state, options: options)
        guard let exactSuggestion = draftState.suggestions.first(where: {
            $0.matchesExactDraft(draft)
        }) else {
            return state
        }
        return draftState.replacingDraft(with: exactSuggestion.insertionToken, addsTrailingSpace: exactSuggestion.isAtomic)
    }

    func replacingDraftForEditing(with draft: String) -> String {
        var parts = split(query)
        parts.draft = draft
        return normalizedQuerySpacing((parts.committedTokens + [parts.draft]).joined(separator: " "))
    }

    func replacingDraftOrCommittingExactAtomicToken(with draft: String) -> String {
        let editedQuery = replacingDraftForEditing(with: draft)
        let editedState = HomeAdvancedQueryInputState(query: editedQuery, options: options)
        guard editedState.shouldCommitExactAtomicDraft else {
            return editedQuery
        }
        return editedState.committingDraft()
    }

    func normalizingCommittedAtomicTokens() -> String {
        guard query.last?.isWhitespace == true else {
            return query
        }

        let parts = split(query)
        let normalizedTokens = parts.committedTokens.map { token in
            atomicSuggestion(for: token)?.insertionToken ?? token
        }
        return normalizedQuerySpacing(normalizedTokens.joined(separator: " "), addsTrailingSpace: true)
    }

    func removingToken(at index: Int) -> String {
        var parts = split(query)
        guard parts.committedTokens.indices.contains(index) else {
            return query
        }
        parts.committedTokens.remove(at: index)
        return normalizedQuerySpacing(
            (parts.committedTokens + [parts.draft]).joined(separator: " "),
            addsTrailingSpace: !parts.committedTokens.isEmpty && parts.draft.isEmpty
        )
    }

    private func replacingDraft(with token: String, addsTrailingSpace: Bool) -> String {
        var parts = split(query)
        if parts.draft.isEmpty {
            parts.committedTokens.append(token)
        } else {
            parts.draft = token
        }
        return normalizedQuerySpacing(
            (parts.committedTokens + [parts.draft]).joined(separator: " "),
            addsTrailingSpace: addsTrailingSpace
        )
    }

    private func committingCurrentDraftAsTyped() -> String {
        let parts = split(query)
        guard !parts.draft.isEmpty else {
            return normalizedQuerySpacing(query)
        }
        return normalizedQuerySpacing(
            (parts.committedTokens + [parts.draft]).joined(separator: " "),
            addsTrailingSpace: true
        )
    }

    private func normalizedQuerySpacing(_ value: String, addsTrailingSpace: Bool = false) -> String {
        let normalized = value
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
        return addsTrailingSpace && !normalized.isEmpty ? "\(normalized) " : normalized
    }

    func displayParts(for token: String) -> [HomeAdvancedQueryDisplayPart] {
        if token.isAdvancedQueryOperator {
            return [HomeAdvancedQueryDisplayPart(title: token.uppercased(), kind: .conjunction)]
        }

        var rawToken = token
        var isNegated = false
        if rawToken.hasPrefix("-") {
            isNegated = true
            rawToken.removeFirst()
        }

        guard let separatorIndex = rawToken.firstIndex(of: ":") else {
            return [HomeAdvancedQueryDisplayPart(title: token, kind: .value)]
        }

        let field = String(rawToken[..<separatorIndex])
        let valueStart = rawToken.index(after: separatorIndex)
        let rawValue = String(rawToken[valueStart...])
        let parsed = Self.parsedComparisonPrefix(rawValue)
        let keyTitle = isNegated ? "-\(field)" : field

        var parts = [
            HomeAdvancedQueryDisplayPart(title: keyTitle, kind: .key),
            HomeAdvancedQueryDisplayPart(title: ":", kind: .operatorToken)
        ]
        if let comparison = parsed.comparison {
            parts.append(HomeAdvancedQueryDisplayPart(title: comparison, kind: .operatorToken))
        }
        if !parsed.value.isEmpty {
            parts.append(HomeAdvancedQueryDisplayPart(title: parsed.value, kind: .value))
        }
        return parts
    }

    private func atomicSuggestion(for token: String) -> HomeAdvancedQuerySuggestion? {
        let normalizedToken = token.normalizedAdvancedQueryToken
        let tokenState = HomeAdvancedQueryInputState(query: token, options: options)
        let matches = tokenState.suggestions.filter {
            $0.insertionToken.normalizedAdvancedQueryToken.hasPrefix(normalizedToken)
        }
        return matches.count == 1 ? matches[0] : nil
    }

    private func split(_ value: String) -> QueryParts {
        let hasTrailingSpace = value.last?.isWhitespace == true
        let rawTokens = value
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !rawTokens.isEmpty else {
            return QueryParts(committedTokens: [], draft: "")
        }

        if hasTrailingSpace {
            return QueryParts(committedTokens: rawTokens, draft: "")
        }

        return QueryParts(
            committedTokens: Array(rawTokens.dropLast()),
            draft: rawTokens.last ?? ""
        )
    }

    private struct QueryParts: Equatable {
        var committedTokens: [String]
        var draft: String
    }
}

struct HomeAdvancedQueryOptions: Equatable {
    var tags: [String] = []
    var places: [String] = []
}

enum HomeAdvancedQueryPartKind: Equatable {
    case key
    case operatorToken
    case value
    case conjunction

    var color: Color {
        switch self {
        case .key:
            return .blue
        case .operatorToken:
            return .orange
        case .value:
            return .green
        case .conjunction:
            return .purple
        }
    }
}

struct HomeAdvancedQueryDisplayPart: Identifiable, Equatable {
    var title: String
    var kind: HomeAdvancedQueryPartKind

    var id: String { "\(kind)-\(title)" }
}

private enum HomeAdvancedQueryDraftContext: Equatable {
    case key(prefix: String)
    case operatorToken(field: HomeAdvancedQueryField)
    case value(field: HomeAdvancedQueryField, comparison: String?, prefix: String)
}

private enum HomeAdvancedQueryField: String, CaseIterable, Equatable {
    case tag
    case place
    case type
    case state
    case due
    case pressure
    case priority
    case importance
    case urgency

    var queryKey: String {
        switch self {
        case .state:
            return "is"
        default:
            return rawValue
        }
    }

    var aliases: [String] {
        switch self {
        case .tag:
            return ["tags"]
        case .place:
            return ["location"]
        case .type:
            return ["kind"]
        case .state:
            return ["status", "state"]
        default:
            return []
        }
    }

    var title: String {
        switch self {
        case .state:
            return "is"
        default:
            return rawValue
        }
    }

    var description: String {
        switch self {
        case .tag:
            return "Task tag"
        case .place:
            return "Routine place"
        case .type:
            return "Task type"
        case .state:
            return "Task state"
        case .due:
            return "Due date"
        case .pressure:
            return "Pressure"
        case .priority:
            return "Priority"
        case .importance:
            return "Importance"
        case .urgency:
            return "Urgency"
        }
    }

    var valueDescription: String {
        switch self {
        case .tag:
            return "Tag value"
        case .place:
            return "Place value"
        default:
            return description
        }
    }

    var supportsComparison: Bool {
        switch self {
        case .pressure, .priority, .importance, .urgency:
            return true
        default:
            return false
        }
    }
}

private extension HomeAdvancedQueryInputState {
    var suggestionCandidates: [HomeAdvancedQuerySuggestion] {
        if draft.isEmpty, shouldSuggestOperators {
            return Self.operatorSuggestions
        }

        switch draftContext {
        case .key(let prefix):
            if let field = Self.field(for: prefix) {
                return Self.operatorSuggestions(for: field)
            }
            return Self.keySuggestions
        case .operatorToken(let field):
            return Self.operatorSuggestions(for: field)
        case .value(let field, let comparison, _):
            return valueSuggestions(for: field, comparison: comparison)
        }
    }

    var shouldSuggestOperators: Bool {
        guard query.last?.isWhitespace == true, let lastToken = tokens.last else {
            return false
        }
        return !lastToken.isAdvancedQueryOperator
    }

    var shouldCommitExactAtomicDraft: Bool {
        guard !draft.isEmpty else { return false }
        guard let exactSuggestion = suggestions.first(where: {
            $0.matchesExactDraft(draft)
        }) else {
            return false
        }
        return exactSuggestion.isAtomic
    }

    var draftContext: HomeAdvancedQueryDraftContext {
        guard let separatorIndex = draft.firstIndex(of: ":") else {
            return .key(prefix: draft)
        }

        let rawField = String(draft[..<separatorIndex])
        guard let field = Self.field(for: rawField) else {
            return .key(prefix: rawField)
        }

        let valueStart = draft.index(after: separatorIndex)
        let rawValue = String(draft[valueStart...])
        if rawValue.isEmpty {
            return .value(field: field, comparison: nil, prefix: "")
        }

        let parsed = Self.parsedComparisonPrefix(rawValue)
        if field.supportsComparison, rawValue == parsed.comparison {
            return .value(field: field, comparison: parsed.comparison, prefix: "")
        }
        return .value(field: field, comparison: parsed.comparison, prefix: parsed.value)
    }

    func valueSuggestions(
        for field: HomeAdvancedQueryField,
        comparison: String?
    ) -> [HomeAdvancedQuerySuggestion] {
        let values: [(title: String, queryValue: String)] = switch field {
        case .tag:
            options.tags.map { ($0, Self.queryValue($0)) }.uniquedByQueryValue()
        case .place:
            options.places.map { ($0, Self.queryValue($0)) }.uniquedByQueryValue()
        case .type:
            [("Todo", "todo"), ("Routine", "routine")]
        case .state:
            [
                ("Done", "done"),
                ("Pinned", "pinned"),
                ("Blocked", "blocked"),
                ("Ready", "ready"),
                ("In progress", "inprogress"),
                ("Paused", "paused")
            ]
        case .due:
            [("Overdue", "overdue"), ("Today", "today"), ("Soon", "soon"), ("Future", "future")]
        case .pressure:
            [("Low", "low"), ("Medium", "medium"), ("High", "high")]
        case .priority:
            [("Low", "low"), ("Medium", "medium"), ("High", "high")]
        case .importance, .urgency:
            [("L1", "l1"), ("L2", "l2"), ("L3", "l3"), ("L4", "l4")]
        }

        return values.map { title, queryValue in
            let operatorPrefix = comparison ?? ""
            return HomeAdvancedQuerySuggestion(
                token: title,
                replacementToken: "\(field.queryKey):\(operatorPrefix)\(queryValue)",
                description: field.valueDescription,
                kind: .value
            )
        }
    }

    static func operatorSuggestions(for field: HomeAdvancedQueryField) -> [HomeAdvancedQuerySuggestion] {
        var suggestions = [
            HomeAdvancedQuerySuggestion(
                token: ":",
                replacementToken: "\(field.queryKey):",
                description: "Match a value",
                kind: .operatorToken
            )
        ]

        if field.supportsComparison {
            suggestions.append(contentsOf: [
                HomeAdvancedQuerySuggestion(
                    token: ">",
                    replacementToken: "\(field.queryKey):>",
                    description: "Greater than",
                    kind: .operatorToken
                ),
                HomeAdvancedQuerySuggestion(
                    token: ">=",
                    replacementToken: "\(field.queryKey):>=",
                    description: "Greater than or equal",
                    kind: .operatorToken
                ),
                HomeAdvancedQuerySuggestion(
                    token: "<",
                    replacementToken: "\(field.queryKey):<",
                    description: "Less than",
                    kind: .operatorToken
                ),
                HomeAdvancedQuerySuggestion(
                    token: "<=",
                    replacementToken: "\(field.queryKey):<=",
                    description: "Less than or equal",
                    kind: .operatorToken
                )
            ])
        }

        return suggestions
    }

    static func queryValue(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .filter { !$0.isWhitespace }
    }

    static func field(for value: String) -> HomeAdvancedQueryField? {
        let normalized = value.normalizedAdvancedQueryToken
        return HomeAdvancedQueryField.allCases.first {
            $0.queryKey == normalized || $0.aliases.contains(normalized)
        }
    }

    static func parsedComparisonPrefix(_ value: String) -> (comparison: String?, value: String) {
        for comparison in [">=", "<=", ">", "<"] where value.hasPrefix(comparison) {
            return (comparison, String(value.dropFirst(comparison.count)))
        }
        return (nil, value)
    }
}

private extension Array where Element == (title: String, queryValue: String) {
    func uniquedByQueryValue() -> [(title: String, queryValue: String)] {
        var seen: Set<String> = []
        return filter { value in
            seen.insert(value.queryValue.normalizedAdvancedQueryToken).inserted
        }
    }
}

private extension Array where Element == HomeAdvancedQuerySuggestion {
    var isContextualValueList: Bool {
        !isEmpty && allSatisfy { $0.kind == .value }
    }
}

struct HomeAdvancedQuerySuggestion: Identifiable, Equatable {
    var token: String
    var replacementToken: String?
    var description: String
    var kind: HomeAdvancedQueryPartKind

    var id: String { "\(kind)-\(token)-\(replacementToken ?? "")" }

    var insertionToken: String {
        replacementToken ?? token
    }

    var isAtomic: Bool {
        kind == .value || kind == .conjunction
    }

    fileprivate var searchText: String {
        "\(token) \(insertionToken) \(description)".normalizedAdvancedQueryToken
    }

    fileprivate func matchesPrefix(_ draft: String) -> Bool {
        let normalizedDraft = draft.normalizedAdvancedQueryToken
        let normalizedToken = token.normalizedAdvancedQueryToken
        let normalizedInsertion = insertionToken.normalizedAdvancedQueryToken
        return normalizedToken.hasPrefix(normalizedDraft)
            || normalizedInsertion.hasPrefix(normalizedDraft)
            || normalizedInsertion.hasSuffix(":\(normalizedDraft)")
            || normalizedInsertion.hasSuffix(">\(normalizedDraft)")
            || normalizedInsertion.hasSuffix(">=" + normalizedDraft)
            || normalizedInsertion.hasSuffix("<\(normalizedDraft)")
            || normalizedInsertion.hasSuffix("<=" + normalizedDraft)
    }

    fileprivate func matchesExactDraft(_ draft: String) -> Bool {
        let normalizedDraft = draft.normalizedAdvancedQueryToken
        return token.normalizedAdvancedQueryToken == normalizedDraft
            || insertionToken.normalizedAdvancedQueryToken == normalizedDraft
    }
}

extension HomeAdvancedQueryInputState {
    static let operatorSuggestions: [HomeAdvancedQuerySuggestion] = [
        HomeAdvancedQuerySuggestion(token: "AND", description: "Require another condition", kind: .conjunction),
        HomeAdvancedQuerySuggestion(token: "OR", description: "Match an alternative condition", kind: .conjunction)
    ]

    static let keySuggestions: [HomeAdvancedQuerySuggestion] = HomeAdvancedQueryField.allCases.map {
        HomeAdvancedQuerySuggestion(
            token: $0.title,
            replacementToken: $0.queryKey,
            description: $0.description,
            kind: .key
        )
    }
}

private extension HomeAdvancedQuerySuggestion {
    func ghostSuffix(for draft: String) -> String? {
        guard !draft.isEmpty else { return nil }
        let normalizedDraft = draft.normalizedAdvancedQueryToken
        let normalizedToken = insertionToken.normalizedAdvancedQueryToken
        guard normalizedToken.hasPrefix(normalizedDraft), normalizedToken != normalizedDraft else {
            return nil
        }
        return String(insertionToken.dropFirst(draft.count))
    }
}

private extension String {
    var normalizedAdvancedQueryToken: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isAdvancedQueryOperator: Bool {
        let normalized = normalizedAdvancedQueryToken.uppercased()
        return normalized == "AND" || normalized == "OR"
    }
}

private extension View {
    @ViewBuilder
    func advancedQueryInputTraits() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}
