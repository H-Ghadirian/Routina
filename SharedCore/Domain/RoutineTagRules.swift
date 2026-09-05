import Foundation

/// A behavior attached to one tag. Rules intentionally use a typed, stable
/// kind instead of ad-hoc booleans so future tag behaviors can be added
/// without changing the stored shape of a tag's settings.
enum RoutineTagRuleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case hideFromTaskLists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hideFromTaskLists:
            return "Hide tasks from normal task lists"
        }
    }

    var detail: String {
        switch self {
        case .hideFromTaskLists:
            return "Tasks remain available in search and when this tag is selected."
        }
    }
}

struct RoutineTagRule: Codable, Equatable, Identifiable, Sendable {
    var tag: String
    var kind: RoutineTagRuleKind

    var id: String {
        let normalizedTag = RoutineTag.normalized(tag) ?? tag
        return "\(normalizedTag):\(kind.rawValue)"
    }
}

enum RoutineTagRules {
    static func sanitized(_ rules: [RoutineTagRule]) -> [RoutineTagRule] {
        var rulesByID: [String: RoutineTagRule] = [:]

        for rule in rules {
            guard let cleanedTag = RoutineTag.cleaned(rule.tag),
                let normalizedTag = RoutineTag.normalized(cleanedTag)
            else {
                continue
            }
            rulesByID["\(normalizedTag):\(rule.kind.rawValue)"] = RoutineTagRule(
                tag: cleanedTag,
                kind: rule.kind
            )
        }

        return rulesByID.values.sorted {
            let tagOrder = $0.tag.localizedCaseInsensitiveCompare($1.tag)
            if tagOrder != .orderedSame {
                return tagOrder == .orderedAscending
            }
            return $0.kind.rawValue < $1.kind.rawValue
        }
    }

    static func contains(
        _ kind: RoutineTagRuleKind,
        for tag: String,
        in rules: [RoutineTagRule]
    ) -> Bool {
        guard let normalizedTag = RoutineTag.normalized(tag) else { return false }
        return sanitized(rules).contains {
            $0.kind == kind && RoutineTag.normalized($0.tag) == normalizedTag
        }
    }

    static func hidesFromTaskLists(
        tags: [String],
        rules: [RoutineTagRule]
    ) -> Bool {
        let hiddenTagNames = sanitized(rules)
            .filter { $0.kind == .hideFromTaskLists }
            .map(\.tag)
        return hiddenTagNames.contains { RoutineTag.contains($0, in: tags) }
    }

    static func adding(
        _ kind: RoutineTagRuleKind,
        for tag: String,
        in rules: [RoutineTagRule]
    ) -> [RoutineTagRule] {
        guard let cleanedTag = RoutineTag.cleaned(tag) else { return sanitized(rules) }
        return sanitized(rules + [RoutineTagRule(tag: cleanedTag, kind: kind)])
    }

    static func removing(
        _ kind: RoutineTagRuleKind,
        for tag: String,
        from rules: [RoutineTagRule]
    ) -> [RoutineTagRule] {
        guard let normalizedTag = RoutineTag.normalized(tag) else { return sanitized(rules) }
        return sanitized(rules).filter {
            !($0.kind == kind && RoutineTag.normalized($0.tag) == normalizedTag)
        }
    }

    static func replacing(
        _ tag: String,
        with replacement: String,
        in rules: [RoutineTagRule]
    ) -> [RoutineTagRule] {
        guard let cleanedReplacement = RoutineTag.cleaned(replacement) else {
            return sanitized(rules)
        }

        return sanitized(
            rules.map { rule in
                guard RoutineTag.contains(tag, in: [rule.tag]) else { return rule }
                return RoutineTagRule(tag: cleanedReplacement, kind: rule.kind)
            })
    }

    static func removing(_ tag: String, from rules: [RoutineTagRule]) -> [RoutineTagRule] {
        guard let normalizedTag = RoutineTag.normalized(tag) else { return sanitized(rules) }
        return sanitized(rules).filter { RoutineTag.normalized($0.tag) != normalizedTag }
    }
}
