import Foundation

enum RoutineTag {
    static func cleaned(_ value: String) -> String? {
        let collapsed = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !collapsed.isEmpty else { return nil }
        return collapsed
    }

    static func normalized(_ value: String) -> String? {
        guard let cleaned = cleaned(value) else { return nil }
        return cleaned.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func parseDraft(_ input: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",\n")
        return deduplicated(input.components(separatedBy: separators))
    }

    static func deduplicated(_ tags: [String]) -> [String] {
        var seen = Set<String>()

        return tags.compactMap { rawTag in
            guard
                let cleanedTag = cleaned(rawTag),
                let normalizedTag = normalized(cleanedTag),
                seen.insert(normalizedTag).inserted
            else {
                return nil
            }

            return cleanedTag
        }
    }

    static func appending(_ draft: String, to existingTags: [String]) -> [String] {
        deduplicated(existingTags + parseDraft(draft))
    }

    static func removing(_ tag: String, from existingTags: [String]) -> [String] {
        guard let normalizedTag = normalized(tag) else { return deduplicated(existingTags) }
        return deduplicated(existingTags).filter { normalized($0) != normalizedTag }
    }

    static func contains(_ tag: String, in tags: [String]) -> Bool {
        guard let normalizedTag = normalized(tag) else { return false }
        return tags.contains { normalized($0) == normalizedTag }
    }

    static func matchesQuery(_ query: String, in tags: [String]) -> Bool {
        guard let normalizedQuery = normalized(query) else { return true }
        return tags.contains { normalized($0)?.contains(normalizedQuery) == true }
    }

    static func allTags(from tagCollections: [[String]]) -> [String] {
        deduplicated(tagCollections.flatMap(\.self)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    static func serialize(_ tags: [String]) -> String {
        deduplicated(tags).joined(separator: "\n")
    }

    static func deserialize(_ storage: String?) -> [String] {
        guard let storage else { return [] }
        return deduplicated(storage.components(separatedBy: .newlines))
    }
}
