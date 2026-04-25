import SwiftUI

struct HomeAdvancedQueryBuilder: View {
    @Binding var query: String
    var usesFlowLayout: Bool = false

    @FocusState private var isFocused: Bool

    private var state: HomeAdvancedQueryInputState {
        HomeAdvancedQueryInputState(query: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            queryInput

            if !state.tokens.isEmpty {
                tokenChips
            }

            suggestionRow
        }
    }

    private var queryInput: some View {
        ZStack(alignment: .leading) {
            if isFocused, let ghostSuffix = state.primaryGhostSuffix, !ghostSuffix.isEmpty {
                HStack(spacing: 0) {
                    Text(query)
                        .foregroundStyle(.clear)
                    Text(ghostSuffix)
                        .foregroundStyle(.tertiary)
                }
                .font(.body)
                .padding(.horizontal, 8)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            TextField("tag:work -is:done type:todo", text: $query, axis: .vertical)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
                .advancedQueryInputTraits()
                .lineLimit(1...3)
                .onChange(of: query) { _, newValue in
                    let normalized = HomeAdvancedQueryInputState(query: newValue).normalizingCommittedAtomicTokens()
                    if normalized != newValue {
                        query = normalized
                    }
                }
                .onSubmit { acceptPrimarySuggestionOrCommitDraft() }
                .onKeyPress(SwiftUI.KeyEquivalent.tab) {
                    acceptPrimarySuggestionOrCommitDraft()
                    return SwiftUI.KeyPress.Result.handled
                }
        }
    }

    @ViewBuilder
    private var tokenChips: some View {
        if usesFlowLayout {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(state.tokens.enumerated()), id: \.offset) { index, token in
                    committedTokenChip(token, at: index)
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(state.tokens.enumerated()), id: \.offset) { index, token in
                        committedTokenChip(token, at: index)
                    }
                }
                .padding(.vertical, 2)
            }
        }
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
            Label(token, systemImage: "xmark.circle.fill")
                .labelStyle(.titleAndIcon)
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
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
}

struct HomeAdvancedQueryInputState: Equatable {
    var query: String

    var tokens: [String] {
        split(query).committedTokens
    }

    var draft: String {
        split(query).draft
    }

    var suggestions: [HomeAdvancedQuerySuggestion] {
        let rawDraft = draft
        let normalizedDraft = rawDraft.normalizedAdvancedQueryToken
        let candidates = Self.allSuggestions

        guard !normalizedDraft.isEmpty else {
            return Array(candidates.prefix(10))
        }

        let exactPrefixMatches = candidates.filter {
            $0.token.normalizedAdvancedQueryToken.hasPrefix(normalizedDraft)
        }
        if !exactPrefixMatches.isEmpty {
            return Array(exactPrefixMatches.prefix(8))
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
                && suggestion.token.normalizedAdvancedQueryToken.hasPrefix(normalizedDraft)
                && suggestion.token.normalizedAdvancedQueryToken != normalizedDraft
        }
    }

    var primaryGhostSuffix: String? {
        primarySuggestion?.ghostSuffix(for: draft)
    }

    func accepting(_ suggestion: HomeAdvancedQuerySuggestion) -> String {
        replacingDraft(with: suggestion.token)
    }

    func committingDraft() -> String {
        guard let exactSuggestion = suggestions.first(where: {
            $0.token.normalizedAdvancedQueryToken == draft.normalizedAdvancedQueryToken
        }) else {
            return normalizedQuerySpacing(query)
        }
        return replacingDraft(with: exactSuggestion.token)
    }

    func normalizingCommittedAtomicTokens() -> String {
        guard query.last?.isWhitespace == true else {
            return query
        }

        let parts = split(query)
        let normalizedTokens = parts.committedTokens.map { token in
            atomicSuggestion(for: token)?.token ?? token
        }
        return normalizedQuerySpacing(normalizedTokens.joined(separator: " "), addsTrailingSpace: true)
    }

    func removingToken(at index: Int) -> String {
        var parts = split(query)
        guard parts.committedTokens.indices.contains(index) else {
            return query
        }
        parts.committedTokens.remove(at: index)
        return normalizedQuerySpacing((parts.committedTokens + [parts.draft]).joined(separator: " "))
    }

    private func replacingDraft(with token: String) -> String {
        var parts = split(query)
        if parts.draft.isEmpty {
            parts.committedTokens.append(token)
        } else {
            parts.draft = token
        }
        return normalizedQuerySpacing(
            (parts.committedTokens + [parts.draft]).joined(separator: " "),
            addsTrailingSpace: !token.hasSuffix(":")
        )
    }

    private func normalizedQuerySpacing(_ value: String, addsTrailingSpace: Bool = false) -> String {
        let normalized = value
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
        return addsTrailingSpace && !normalized.isEmpty ? "\(normalized) " : normalized
    }

    private func atomicSuggestion(for token: String) -> HomeAdvancedQuerySuggestion? {
        let normalizedToken = token.normalizedAdvancedQueryToken
        let matches = Self.allSuggestions.filter {
            $0.token.normalizedAdvancedQueryToken.hasPrefix(normalizedToken)
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

struct HomeAdvancedQuerySuggestion: Identifiable, Equatable {
    var token: String
    var description: String

    var id: String { token }

    fileprivate var searchText: String {
        "\(token) \(description)".normalizedAdvancedQueryToken
    }
}

extension HomeAdvancedQueryInputState {
    static let allSuggestions: [HomeAdvancedQuerySuggestion] = [
        HomeAdvancedQuerySuggestion(token: "tag:", description: "Match a tag"),
        HomeAdvancedQuerySuggestion(token: "place:", description: "Match a place"),
        HomeAdvancedQuerySuggestion(token: "type:todo", description: "One-off tasks"),
        HomeAdvancedQuerySuggestion(token: "type:routine", description: "Recurring tasks"),
        HomeAdvancedQuerySuggestion(token: "is:done", description: "Completed tasks"),
        HomeAdvancedQuerySuggestion(token: "-is:done", description: "Not completed"),
        HomeAdvancedQuerySuggestion(token: "is:pinned", description: "Pinned tasks"),
        HomeAdvancedQuerySuggestion(token: "is:blocked", description: "Blocked todos"),
        HomeAdvancedQuerySuggestion(token: "due:overdue", description: "Past due"),
        HomeAdvancedQuerySuggestion(token: "due:today", description: "Due today"),
        HomeAdvancedQuerySuggestion(token: "due:soon", description: "Due within 3 days"),
        HomeAdvancedQuerySuggestion(token: "pressure:low", description: "Low pressure"),
        HomeAdvancedQuerySuggestion(token: "pressure:medium", description: "Medium pressure"),
        HomeAdvancedQuerySuggestion(token: "pressure:high", description: "High pressure"),
        HomeAdvancedQuerySuggestion(token: "pressure:>low", description: "Medium or high pressure"),
        HomeAdvancedQuerySuggestion(token: "pressure:>=medium", description: "Medium or high pressure"),
        HomeAdvancedQuerySuggestion(token: "priority:>low", description: "Priority above low"),
        HomeAdvancedQuerySuggestion(token: "importance:l3", description: "High importance"),
        HomeAdvancedQuerySuggestion(token: "importance:>=l3", description: "High importance or above"),
        HomeAdvancedQuerySuggestion(token: "urgency:l3", description: "High urgency"),
        HomeAdvancedQuerySuggestion(token: "urgency:>=l3", description: "High urgency or above")
    ]
}

private extension HomeAdvancedQuerySuggestion {
    func ghostSuffix(for draft: String) -> String? {
        guard !draft.isEmpty else { return nil }
        let normalizedDraft = draft.normalizedAdvancedQueryToken
        let normalizedToken = token.normalizedAdvancedQueryToken
        guard normalizedToken.hasPrefix(normalizedDraft), normalizedToken != normalizedDraft else {
            return nil
        }
        return String(token.dropFirst(draft.count))
    }
}

private extension String {
    var normalizedAdvancedQueryToken: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
