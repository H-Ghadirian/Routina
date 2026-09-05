import Foundation

struct RoutineRelatedTagRule: Codable, Equatable, Identifiable, Sendable {
    var tag: String
    var relatedTags: [String]

    var id: String {
        RoutineTag.normalized(tag) ?? tag
    }
}

enum RoutineTagRelations {
    static func sanitized(_ rules: [RoutineRelatedTagRule]) -> [RoutineRelatedTagRule] {
        var relatedByTag: [String: (tag: String, relatedTags: [String])] = [:]

        for rule in rules {
            guard let cleanedTag = RoutineTag.cleaned(rule.tag),
                let normalizedTag = RoutineTag.normalized(cleanedTag)
            else {
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
                    !selectedNormalized.contains(normalizedRelated)
                else {
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
        sanitized(
            rules.map { rule in
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
        sanitized(
            rules.compactMap { rule in
                guard !RoutineTag.contains(tag, in: [rule.tag]) else { return nil }
                return RoutineRelatedTagRule(
                    tag: rule.tag,
                    relatedTags: RoutineTag.removing(tag, from: rule.relatedTags)
                )
            })
    }
}
