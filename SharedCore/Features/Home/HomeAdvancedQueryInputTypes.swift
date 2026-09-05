struct HomeAdvancedQueryOptions: Equatable {
    var tags: [String] = []
    var places: [String] = []
}

enum HomeAdvancedQueryPartKind: Equatable {
    case key
    case operatorToken
    case value
    case conjunction
}

struct HomeAdvancedQueryDisplayPart: Identifiable, Equatable {
    var title: String
    var kind: HomeAdvancedQueryPartKind

    var id: String { "\(kind)-\(title)" }
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

    var searchText: String {
        "\(token) \(insertionToken) \(description)".normalizedAdvancedQueryToken
    }

    func matchesPrefix(_ draft: String) -> Bool {
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

    func matchesExactDraft(_ draft: String) -> Bool {
        let normalizedDraft = draft.normalizedAdvancedQueryToken
        return token.normalizedAdvancedQueryToken == normalizedDraft
            || insertionToken.normalizedAdvancedQueryToken == normalizedDraft
    }
}
