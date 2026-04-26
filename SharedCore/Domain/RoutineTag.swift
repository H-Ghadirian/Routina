import Foundation

struct RoutineTagSummary: Equatable, Identifiable, Sendable {
    var name: String
    var linkedRoutineCount: Int
    var doneCount: Int = 0
    var colorHex: String?

    var id: String {
        RoutineTag.normalized(name) ?? name
    }
}

enum RoutineTagColors {
    static func sanitized(_ colorsByTag: [String: String]) -> [String: String] {
        colorsByTag.reduce(into: [String: String]()) { partialResult, entry in
            guard let normalizedTag = RoutineTag.normalized(entry.key),
                  let normalizedHex = normalizedHex(entry.value) else {
                return
            }
            partialResult[normalizedTag] = normalizedHex
        }
    }

    static func colorHex(for tag: String, in colorsByTag: [String: String]) -> String? {
        guard let normalizedTag = RoutineTag.normalized(tag) else { return nil }
        return sanitized(colorsByTag)[normalizedTag]
    }

    static func setting(_ colorHex: String?, for tag: String, in colorsByTag: [String: String]) -> [String: String] {
        guard let normalizedTag = RoutineTag.normalized(tag) else {
            return sanitized(colorsByTag)
        }

        var updatedColors = sanitized(colorsByTag)
        if let normalizedHex = colorHex.flatMap(normalizedHex) {
            updatedColors[normalizedTag] = normalizedHex
        } else {
            updatedColors.removeValue(forKey: normalizedTag)
        }
        return updatedColors
    }

    static func replacing(_ tag: String, with replacement: String, in colorsByTag: [String: String]) -> [String: String] {
        guard let normalizedTag = RoutineTag.normalized(tag),
              let normalizedReplacement = RoutineTag.normalized(replacement) else {
            return sanitized(colorsByTag)
        }

        var updatedColors = sanitized(colorsByTag)
        guard let colorHex = updatedColors.removeValue(forKey: normalizedTag) else {
            return updatedColors
        }
        updatedColors[normalizedReplacement] = colorHex
        return updatedColors
    }

    static func removing(_ tag: String, from colorsByTag: [String: String]) -> [String: String] {
        guard let normalizedTag = RoutineTag.normalized(tag) else {
            return sanitized(colorsByTag)
        }

        var updatedColors = sanitized(colorsByTag)
        updatedColors.removeValue(forKey: normalizedTag)
        return updatedColors
    }

    static func applying(_ colorsByTag: [String: String], to summaries: [RoutineTagSummary]) -> [RoutineTagSummary] {
        summaries.map { summary in
            var updatedSummary = summary
            updatedSummary.colorHex = colorHex(for: summary.name, in: colorsByTag)
            return updatedSummary
        }
    }

    private static func normalizedHex(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard withoutPrefix.count == 6,
              withoutPrefix.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        return "#\(withoutPrefix.uppercased())"
    }
}

struct RoutineRelatedTagRule: Codable, Equatable, Identifiable, Sendable {
    var tag: String
    var relatedTags: [String]

    var id: String {
        RoutineTag.normalized(tag) ?? tag
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
        let tagCounts = tasks.reduce(into: [String: Int]()) { partialResult, task in
            for tag in task.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        return allTags(from: tasks.map(\.tags)).map { tag in
            RoutineTagSummary(
                name: tag,
                linkedRoutineCount: tagCounts[normalized(tag) ?? tag, default: 0]
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

        let doneTagCounts = tasks.reduce(into: [String: Int]()) { partialResult, task in
            let doneCount = countsByTaskID[task.id, default: 0]
            guard doneCount > 0 else { return }

            for tag in task.tags {
                guard let normalizedTag = normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += doneCount
            }
        }

        return allTags(from: tasks.map(\.tags)).map { tag in
            RoutineTagSummary(
                name: tag,
                linkedRoutineCount: linkedTagCounts[normalized(tag) ?? tag, default: 0],
                doneCount: doneTagCounts[normalized(tag) ?? tag, default: 0]
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

    private static func currentDraftToken(in draft: String) -> String {
        draft
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .last
            .flatMap(cleaned) ?? ""
    }
}

enum RoutineTagRelations {
    static func sanitized(_ rules: [RoutineRelatedTagRule]) -> [RoutineRelatedTagRule] {
        var relatedByTag: [String: (tag: String, relatedTags: [String])] = [:]

        for rule in rules {
            guard let cleanedTag = RoutineTag.cleaned(rule.tag),
                  let normalizedTag = RoutineTag.normalized(cleanedTag) else {
                continue
            }

            let relatedTags = RoutineTag.deduplicated(rule.relatedTags).filter {
                RoutineTag.normalized($0) != normalizedTag
            }
            guard !relatedTags.isEmpty else {
                relatedByTag.removeValue(forKey: normalizedTag)
                continue
            }

            let existing = relatedByTag[normalizedTag]?.relatedTags ?? []
            relatedByTag[normalizedTag] = (
                tag: cleanedTag,
                relatedTags: RoutineTag.deduplicated(existing + relatedTags)
            )
        }

        return relatedByTag.values
            .map { RoutineRelatedTagRule(tag: $0.tag, relatedTags: $0.relatedTags) }
            .sorted { $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending }
    }

    static func relatedTags(
        for selectedTags: [String],
        rules: [RoutineRelatedTagRule],
        availableTags: [String],
        limit: Int = 5
    ) -> [String] {
        let selected = RoutineTag.deduplicated(selectedTags)
        guard !selected.isEmpty else { return [] }

        let selectedNormalized = Set(selected.compactMap(RoutineTag.normalized))
        let availableByNormalized = Dictionary(
            uniqueKeysWithValues: RoutineTag.deduplicated(availableTags).compactMap { tag in
                RoutineTag.normalized(tag).map { ($0, tag) }
            }
        )
        var scored: [String: (tag: String, score: Int)] = [:]

        for rule in sanitized(rules) {
            guard let normalizedRuleTag = RoutineTag.normalized(rule.tag) else { continue }
            let isSelected = selectedNormalized.contains(normalizedRuleTag)

            for relatedTag in rule.relatedTags {
                guard let normalizedRelated = RoutineTag.normalized(relatedTag),
                      !selectedNormalized.contains(normalizedRelated) else {
                    continue
                }

                let candidateTag = availableByNormalized[normalizedRelated] ?? relatedTag
                let score = isSelected ? 4 : (selectedNormalized.contains(normalizedRelated) ? 2 : 0)
                guard score > 0 else { continue }

                let current = scored[normalizedRelated]
                scored[normalizedRelated] = (
                    tag: candidateTag,
                    score: max(current?.score ?? 0, score)
                )
            }

            if selectedNormalized.contains(where: { selectedTag in
                rule.relatedTags.contains { RoutineTag.normalized($0) == selectedTag }
            }) {
                guard !selectedNormalized.contains(normalizedRuleTag) else { continue }
                let candidateTag = availableByNormalized[normalizedRuleTag] ?? rule.tag
                let current = scored[normalizedRuleTag]
                scored[normalizedRuleTag] = (
                    tag: candidateTag,
                    score: max(current?.score ?? 0, 2)
                )
            }
        }

        return scored.values
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
            }
            .map(\.tag)
            .prefix(limit)
            .map { $0 }
    }

    static func learnedRules(from tagCollections: [[String]]) -> [RoutineRelatedTagRule] {
        var counts: [String: (tag: String, related: [String: (tag: String, count: Int)])] = [:]

        for tags in tagCollections {
            let deduped = RoutineTag.deduplicated(tags)
            guard deduped.count > 1 else { continue }

            for tag in deduped {
                guard let normalizedTag = RoutineTag.normalized(tag) else { continue }
                var entry = counts[normalizedTag] ?? (tag: tag, related: [:])

                for relatedTag in deduped where !RoutineTag.contains(relatedTag, in: [tag]) {
                    guard let normalizedRelatedTag = RoutineTag.normalized(relatedTag) else { continue }
                    let relatedEntry = entry.related[normalizedRelatedTag] ?? (tag: relatedTag, count: 0)
                    entry.related[normalizedRelatedTag] = (
                        tag: relatedEntry.tag,
                        count: relatedEntry.count + 1
                    )
                }

                counts[normalizedTag] = entry
            }
        }

        return counts.values.compactMap { entry in
            let relatedTags = entry.related.values
                .sorted {
                    if $0.count != $1.count { return $0.count > $1.count }
                    return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
                }
                .prefix(5)
                .map(\.tag)

            guard !relatedTags.isEmpty else { return nil }
            return RoutineRelatedTagRule(tag: entry.tag, relatedTags: relatedTags)
        }
        .sorted { $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending }
    }

    static func replacing(
        _ tag: String,
        with replacement: String,
        in rules: [RoutineRelatedTagRule]
    ) -> [RoutineRelatedTagRule] {
        sanitized(rules.map { rule in
            RoutineRelatedTagRule(
                tag: RoutineTag.contains(tag, in: [rule.tag]) ? replacement : rule.tag,
                relatedTags: rule.relatedTags.map {
                    RoutineTag.contains(tag, in: [$0]) ? replacement : $0
                }
            )
        })
    }

    static func removing(
        _ tag: String,
        from rules: [RoutineRelatedTagRule]
    ) -> [RoutineRelatedTagRule] {
        sanitized(rules.compactMap { rule in
            guard !RoutineTag.contains(tag, in: [rule.tag]) else { return nil }
            return RoutineRelatedTagRule(
                tag: rule.tag,
                relatedTags: RoutineTag.removing(tag, from: rule.relatedTags)
            )
        })
    }
}
