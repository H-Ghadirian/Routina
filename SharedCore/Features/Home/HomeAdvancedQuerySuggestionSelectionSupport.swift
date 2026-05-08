import Foundation

enum HomeAdvancedQuerySuggestionSelectionSupport {
    static func suggestions(
        draft: String,
        candidates: [HomeAdvancedQuerySuggestion]
    ) -> [HomeAdvancedQuerySuggestion] {
        let normalizedDraft = draft.normalizedAdvancedQueryToken
        guard !normalizedDraft.isEmpty else {
            return candidates
        }

        let exactPrefixMatches = candidates.filter {
            $0.matchesPrefix(draft)
        }
        if !exactPrefixMatches.isEmpty {
            return Array(exactPrefixMatches.prefix(candidates.isContextualValueList ? candidates.count : 8))
        }

        let fieldScopedMatches = candidates.filter {
            $0.searchText.contains(normalizedDraft)
        }
        return Array(fieldScopedMatches.prefix(8))
    }

    static func primarySuggestion(
        draft: String,
        suggestions: [HomeAdvancedQuerySuggestion]
    ) -> HomeAdvancedQuerySuggestion? {
        let normalizedDraft = draft.normalizedAdvancedQueryToken
        return suggestions.first { suggestion in
            !normalizedDraft.isEmpty
                && suggestion.insertionToken.normalizedAdvancedQueryToken.hasPrefix(normalizedDraft)
                && suggestion.insertionToken.normalizedAdvancedQueryToken != normalizedDraft
        }
    }
}

private extension Array where Element == HomeAdvancedQuerySuggestion {
    var isContextualValueList: Bool {
        !isEmpty && allSatisfy { $0.kind == .value }
    }
}
