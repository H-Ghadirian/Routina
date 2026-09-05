import Foundation

/// A conservative, human-confirmed proposal to merge two inflection variants.
/// It never changes persisted tags by itself.
struct RoutineTagNormalizationSuggestion: Equatable, Identifiable, Sendable {
    let source: RoutineTagSummary
    let replacement: RoutineTagSummary

    var id: String {
        "\(source.id)->\(replacement.id)"
    }
}

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

    /// Finds conservative English inflection variants such as `clean` and
    /// `Cleaning`. Semantic matching is deliberately out of scope: a person
    /// must first confirm every proposal before the global rename is performed.
    static func normalizationSuggestions(
        from summaries: [RoutineTagSummary]
    ) -> [RoutineTagNormalizationSuggestion] {
        let groups = Dictionary(grouping: summaries) { normalizationKey(for: $0.name) }

        return groups.values.flatMap { group -> [RoutineTagNormalizationSuggestion] in
            let validGroup = group.compactMap { summary -> RoutineTagSummary? in
                normalizationKey(for: summary.name) == nil ? nil : summary
            }
            guard validGroup.count > 1 else { return [] }

            let ordered = validGroup.sorted(by: normalizationPreference)
            guard let replacement = ordered.first else { return [] }
            return ordered.dropFirst().map {
                RoutineTagNormalizationSuggestion(source: $0, replacement: replacement)
            }
        }
        .sorted { lhs, rhs in
            let sourceComparison = lhs.source.name.localizedCaseInsensitiveCompare(rhs.source.name)
            if sourceComparison != .orderedSame {
                return sourceComparison == .orderedAscending
            }
            return lhs.replacement.name.localizedCaseInsensitiveCompare(rhs.replacement.name) == .orderedAscending
        }
    }

    private static func normalizationPreference(
        _ lhs: RoutineTagSummary,
        _ rhs: RoutineTagSummary
    ) -> Bool {
        if lhs.totalLinkedItemCount != rhs.totalLinkedItemCount {
            return lhs.totalLinkedItemCount > rhs.totalLinkedItemCount
        }
        if lhs.name.count != rhs.name.count {
            return lhs.name.count < rhs.name.count
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func normalizationKey(for value: String) -> String? {
        guard let cleaned = cleaned(value) else { return nil }
        let words = cleaned
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split(separator: " ")
        guard !words.isEmpty,
              words.allSatisfy({ $0.allSatisfy(\.isLetter) }) else {
            return nil
        }
        return words.map { inflectionStem(String($0)) }.joined(separator: " ")
    }

    private static func inflectionStem(_ word: String) -> String {
        guard word.count > 3 else { return word }

        if word.count > 5, word.hasSuffix("ies") {
            return "\(word.dropLast(3))y"
        }

        if word.count > 5, word.hasSuffix("ing") {
            var stem = String(word.dropLast(3))
            let characters = Array(stem)
            if characters.count >= 2, characters[characters.count - 1] == characters[characters.count - 2] {
                stem.removeLast()
            }
            return stem
        }

        let usesPluralSuffix = word.hasSuffix("xes")
            || word.hasSuffix("zes")
            || word.hasSuffix("ches")
            || word.hasSuffix("shes")
        if word.count > 4, usesPluralSuffix {
            return String(word.dropLast(2))
        }

        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss") {
            return String(word.dropLast())
        }

        return word
    }

    static func parseDraft(_ input: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",\n")
        return deduplicated(input.components(separatedBy: separators))
    }

    static func deduplicated(_ tags: [String], preferredTags: [String] = []) -> [String] {
        var seen = Set<String>()
        let preferredTagsByNormalized = preferredDisplayTagsByNormalized(preferredTags)

        return tags.compactMap { rawTag in
            guard
                let cleanedTag = cleaned(rawTag),
                let normalizedTag = normalized(cleanedTag),
                seen.insert(normalizedTag).inserted
            else {
                return nil
            }

            return preferredTagsByNormalized[normalizedTag] ?? cleanedTag
        }
    }

    static func appending(_ draft: String, to existingTags: [String]) -> [String] {
        deduplicated(existingTags + parseDraft(draft))
    }

    static func appending(
        _ draft: String,
        to existingTags: [String],
        availableTags: [String]
    ) -> [String] {
        deduplicated(
            existingTags + parseDraft(draft),
            preferredTags: availableTags + existingTags
        )
    }

    static func merging(
        _ tags: [String],
        into existingTags: [String],
        availableTags: [String]
    ) -> [String] {
        deduplicated(existingTags + tags, preferredTags: availableTags + existingTags)
    }

    static func autocompleteSuggestion(
        for draft: String,
        availableTags: [String],
        selectedTags: [String]
    ) -> String? {
        let token = currentDraftToken(in: draft)
        guard let normalizedToken = normalized(token) else { return nil }

        return availableTags.first { tag in
            guard !contains(tag, in: selectedTags),
                  let normalizedTag = normalized(tag),
                  normalizedTag != normalizedToken else {
                return false
            }
            return normalizedTag.hasPrefix(normalizedToken)
        }
    }

    static func acceptingAutocompleteSuggestion(_ suggestion: String, in draft: String) -> String {
        guard let cleanedSuggestion = cleaned(suggestion) else { return draft }
        guard let tokenStart = draft.lastIndex(where: { $0 == "," || $0 == "\n" }) else {
            return cleanedSuggestion
        }

        let prefix = draft[...tokenStart]
        let separator = draft[tokenStart] == "," ? " " : ""
        return "\(prefix)\(separator)\(cleanedSuggestion)"
    }

    static func removing(_ tag: String, from existingTags: [String]) -> [String] {
        guard let normalizedTag = normalized(tag) else { return deduplicated(existingTags) }
        return deduplicated(existingTags).filter { normalized($0) != normalizedTag }
    }

    static func replacing(_ tag: String, with replacement: String, in existingTags: [String]) -> [String] {
        guard
            let normalizedTag = normalized(tag),
            let cleanedReplacement = cleaned(replacement),
            let normalizedReplacement = normalized(cleanedReplacement)
        else {
            return deduplicated(existingTags)
        }

        var seen = Set<String>()
        var didReplace = false
        var updatedTags: [String] = []

        for existingTag in existingTags {
            guard
                let cleanedExistingTag = cleaned(existingTag),
                let normalizedExistingTag = normalized(cleanedExistingTag)
            else {
                continue
            }

            if normalizedExistingTag == normalizedTag {
                if !didReplace, seen.insert(normalizedReplacement).inserted {
                    updatedTags.append(cleanedReplacement)
                }
                didReplace = true
                continue
            }

            guard seen.insert(normalizedExistingTag).inserted else { continue }
            updatedTags.append(cleanedExistingTag)
        }

        if !didReplace, seen.insert(normalizedReplacement).inserted {
            updatedTags.append(cleanedReplacement)
        }

        return updatedTags
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

    static func summaries(from tasks: [RoutineTask]) -> [RoutineTagSummary] {
        summaries(from: tasks, goals: [], notes: [], events: [])
    }

    static func summaries(from tasks: [RoutineTask], goals: [RoutineGoal]) -> [RoutineTagSummary] {
        summaries(from: tasks, goals: goals, notes: [], events: [])
    }

    static func summaries(
        from tasks: [RoutineTask],
        goals: [RoutineGoal],
        notes: [RoutineNote],
        events: [RoutineEvent] = []
    ) -> [RoutineTagSummary] {
        let tagCounts = tasks.reduce(into: [String: Int]()) { partialResult, task in
            for tag in task.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        let todoTagCounts = tasks.reduce(into: [String: Int]()) { partialResult, task in
            guard task.isOneOffTask else { return }
            for tag in task.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        let goalTagCounts = goals.reduce(into: [String: Int]()) { partialResult, goal in
            for tag in goal.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        let noteTagCounts = notes.reduce(into: [String: Int]()) { partialResult, note in
            for tag in note.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        let eventTagCounts = events.reduce(into: [String: Int]()) { partialResult, event in
            for tag in event.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        return allTags(from: tasks.map(\.tags) + goals.map(\.tags) + notes.map(\.tags) + events.map(\.tags)).map { tag in
            let key = normalized(tag) ?? tag
            return RoutineTagSummary(
                name: tag,
                linkedRoutineCount: tagCounts[key, default: 0],
                linkedTodoCount: todoTagCounts[key, default: 0],
                linkedGoalCount: goalTagCounts[key, default: 0],
                linkedNoteCount: noteTagCounts[key, default: 0],
                linkedEventCount: eventTagCounts[key, default: 0]
            )
        }
    }

    static func summaries(
        from tasks: [RoutineTask],
        countsByTaskID: [UUID: Int]
    ) -> [RoutineTagSummary] {
        let linkedTagCounts = tasks.reduce(into: [String: Int]()) { partialResult, task in
            for tag in task.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        let todoTagCounts = tasks.reduce(into: [String: Int]()) { partialResult, task in
            guard task.isOneOffTask else { return }
            for tag in task.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        let doneTagCounts = tasks.reduce(into: [String: Int]()) { partialResult, task in
            let doneCount = countsByTaskID[task.id, default: 0]
            guard doneCount > 0 else { return }

            for tag in task.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += doneCount
            }
        }

        return allTags(from: tasks.map(\.tags)).map { tag in
            let key = normalized(tag) ?? tag
            return RoutineTagSummary(
                name: tag,
                linkedRoutineCount: linkedTagCounts[key, default: 0],
                doneCount: doneTagCounts[key, default: 0],
                linkedTodoCount: todoTagCounts[key, default: 0]
            )
        }
    }

    static func serialize(_ tags: [String]) -> String {
        deduplicated(tags).joined(separator: "\n")
    }

    static func deserialize(_ storage: String?) -> [String] {
        guard let storage else { return [] }
        return deduplicated(storage.components(separatedBy: .newlines))
    }

    private static func preferredDisplayTagsByNormalized(_ tags: [String]) -> [String: String] {
        tags.reduce(into: [String: String]()) { partialResult, tag in
            guard let cleanedTag = cleaned(tag),
                  let normalizedTag = normalized(cleanedTag),
                  partialResult[normalizedTag] == nil else {
                return
            }
            partialResult[normalizedTag] = cleanedTag
        }
    }

    private static func currentDraftToken(in draft: String) -> String {
        draft
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .last
            .flatMap(cleaned) ?? ""
    }
}
