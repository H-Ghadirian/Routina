import Foundation

struct RoutineTagSummary: Equatable, Identifiable, Sendable {
    var name: String
    var linkedRoutineCount: Int
    var doneCount: Int = 0
    var linkedTodoCount: Int = 0
    var linkedGoalCount: Int = 0
    var linkedNoteCount: Int = 0
    var linkedEventCount: Int = 0
    var colorHex: String?

    var id: String {
        RoutineTag.normalized(name) ?? name
    }

    var totalLinkedItemCount: Int {
        linkedRoutineCount + linkedGoalCount + linkedNoteCount + linkedEventCount
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

/// Flags are task-only markers for Routina behavior. Unlike tags, they never
/// group, color, or relate work across other kinds of content.
enum RoutineFlag {
    static func cleaned(_ value: String) -> String? {
        RoutineTag.cleaned(value)
    }

    static func normalized(_ value: String) -> String? {
        RoutineTag.normalized(value)
    }

    static func parseDraft(_ value: String) -> [String] {
        RoutineTag.parseDraft(value)
    }

    static func deduplicated(_ flags: [String], preferredFlags: [String] = []) -> [String] {
        RoutineTag.deduplicated(flags, preferredTags: preferredFlags)
    }

    static func appending(_ draft: String, to flags: [String], availableFlags: [String] = []) -> [String] {
        RoutineTag.appending(draft, to: flags, availableTags: availableFlags)
    }

    static func removing(_ flag: String, from flags: [String]) -> [String] {
        RoutineTag.removing(flag, from: flags)
    }

    static func contains(_ flag: String, in flags: [String]) -> Bool {
        RoutineTag.contains(flag, in: flags)
    }

    static func matchesQuery(_ query: String, in flags: [String]) -> Bool {
        RoutineTag.matchesQuery(query, in: flags)
    }

    static func allFlags(from flagCollections: [[String]]) -> [String] {
        RoutineTag.allTags(from: flagCollections)
    }

    static func serialize(_ flags: [String]) -> String {
        RoutineTag.serialize(flags)
    }

    static func deserialize(_ value: String) -> [String] {
        RoutineTag.deserialize(value)
    }
}

/// A typed behavior attached to a task flag. A flag can carry one rule of each
/// kind, allowing future behavior to be added without changing persisted data.
enum RoutineFlagRuleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case hideFromTaskLists
    case hideFromCalendarList
    case hideFromTimeline
    case hideFromTaskLadder
    case autoAssumeDone

    var id: String { rawValue }

    /// The reserved, stable flag name used by the built-in behavior model.
    /// These names are persisted so assignments remain portable across devices
    /// and do not depend on the person's display language.
    var builtInFlagName: String {
        switch self {
        case .hideFromTaskLists:
            return "Hide from Task Lists"
        case .hideFromCalendarList:
            return "Hide from Calendar List"
        case .hideFromTimeline:
            return "Hide from Timeline"
        case .hideFromTaskLadder:
            return "Hide from Task Ladder"
        case .autoAssumeDone:
            return "Auto Assume Done"
        }
    }

    var title: String {
        switch self {
        case .hideFromTaskLists:
            return "Hide tasks from normal task lists"
        case .hideFromCalendarList:
            return "Hide tasks from Calendar List"
        case .hideFromTimeline:
            return "Hide task activity from Timeline"
        case .hideFromTaskLadder:
            return "Hide tasks from Task Ladder"
        case .autoAssumeDone:
            return "Enable auto-assume done"
        }
    }

    var detail: String {
        switch self {
        case .hideFromTaskLists:
            return "Tasks remain available when you search for them."
        case .hideFromCalendarList:
            return "Tasks remain visible in Calendar Schedule and other views."
        case .hideFromTimeline:
            return "Task activity remains available when this Flag is selected in Timeline filters."
        case .hideFromTaskLadder:
            return "Tasks remain available in other task views."
        case .autoAssumeDone:
            return "Eligible tasks are automatically marked done after their scheduled time."
        }
    }

    var systemImage: String {
        switch self {
        case .hideFromTaskLists:
            return "eye.slash"
        case .hideFromCalendarList:
            return "calendar.badge.minus"
        case .hideFromTimeline:
            return "clock.badge.xmark"
        case .hideFromTaskLadder:
            return "list.number"
        case .autoAssumeDone:
            return "checkmark.circle"
        }
    }

    static var builtInFlags: [String] {
        allCases.map(\.builtInFlagName)
    }

    static var builtInRules: [RoutineFlagRule] {
        RoutineFlagRules.sanitized(
            allCases.map { RoutineFlagRule(flag: $0.builtInFlagName, kind: $0) }
        )
    }

    /// Keeps the settings catalog canonical for fresh installs and settings
    /// restores. This does not inspect or rewrite task assignments.
    @MainActor
    static func ensureBuiltInCatalog(using appSettingsClient: AppSettingsClient) {
        if appSettingsClient.definedFlags() != builtInFlags {
            appSettingsClient.setDefinedFlags(builtInFlags)
        }
        if RoutineFlagRules.sanitized(appSettingsClient.flagRules()) != builtInRules {
            appSettingsClient.setFlagRules(builtInRules)
        }
    }
}

struct RoutineFlagRule: Codable, Equatable, Identifiable, Sendable {
    var flag: String
    var kind: RoutineFlagRuleKind

    var id: String {
        let normalizedFlag = RoutineFlag.normalized(flag) ?? flag
        return "\(normalizedFlag):\(kind.rawValue)"
    }
}

enum RoutineFlagRules {
    static func sanitized(_ rules: [RoutineFlagRule]) -> [RoutineFlagRule] {
        var rulesByID: [String: RoutineFlagRule] = [:]

        for rule in rules {
            guard let cleanedFlag = RoutineFlag.cleaned(rule.flag),
                  let normalizedFlag = RoutineFlag.normalized(cleanedFlag) else {
                continue
            }
            rulesByID["\(normalizedFlag):\(rule.kind.rawValue)"] = RoutineFlagRule(
                flag: cleanedFlag,
                kind: rule.kind
            )
        }

        return rulesByID.values.sorted {
            let flagOrder = $0.flag.localizedCaseInsensitiveCompare($1.flag)
            if flagOrder != .orderedSame {
                return flagOrder == .orderedAscending
            }
            return $0.kind.rawValue < $1.kind.rawValue
        }
    }

    static func contains(
        _ kind: RoutineFlagRuleKind,
        for flag: String,
        in rules: [RoutineFlagRule]
    ) -> Bool {
        guard let normalizedFlag = RoutineFlag.normalized(flag) else { return false }
        return sanitized(rules).contains {
            $0.kind == kind && RoutineFlag.normalized($0.flag) == normalizedFlag
        }
    }

    static func normalizedFlagIDs(
        for kind: RoutineFlagRuleKind,
        in rules: [RoutineFlagRule]
    ) -> Set<String> {
        Set(
            sanitized(rules)
                .lazy
                .filter { $0.kind == kind }
                .compactMap { RoutineFlag.normalized($0.flag) }
        )
    }

    static func hidesFromTaskLists(
        flags: [String],
        rules: [RoutineFlagRule]
    ) -> Bool {
        !flagsHidingFromTaskLists(flags, rules: rules).isEmpty
    }

    static func hidesFromCalendarList(
        flags: [String],
        rules: [RoutineFlagRule]
    ) -> Bool {
        containsConfiguredFlag(.hideFromCalendarList, in: flags, rules: rules)
    }

    static func enablesAutoAssumeDone(
        flags: [String],
        rules: [RoutineFlagRule]
    ) -> Bool {
        containsConfiguredFlag(.autoAssumeDone, in: flags, rules: rules)
    }

    static func hidesFromTimeline(
        flags: [String],
        rules: [RoutineFlagRule]
    ) -> Bool {
        containsConfiguredFlag(.hideFromTimeline, in: flags, rules: rules)
    }

    static func hidesFromTaskLadder(
        flags: [String],
        rules: [RoutineFlagRule]
    ) -> Bool {
        containsConfiguredFlag(.hideFromTaskLadder, in: flags, rules: rules)
    }

    /// Returns the assigned Flags whose configured behavior hides a task from
    /// normal task-list placement. The task's own spelling is retained for UI.
    static func flagsHidingFromTaskLists(
        _ flags: [String],
        rules: [RoutineFlagRule]
    ) -> [String] {
        let hiddenFlagIDs = Set(
            sanitized(rules)
                .lazy
                .filter { $0.kind == .hideFromTaskLists }
                .compactMap { RoutineFlag.normalized($0.flag) }
        )

        return RoutineFlag.deduplicated(flags).filter { flag in
            guard let normalizedFlag = RoutineFlag.normalized(flag) else { return false }
            return hiddenFlagIDs.contains(normalizedFlag)
        }
    }

    private static func containsConfiguredFlag(
        _ kind: RoutineFlagRuleKind,
        in flags: [String],
        rules: [RoutineFlagRule]
    ) -> Bool {
        let configuredFlagIDs = normalizedFlagIDs(for: kind, in: rules)
        return flags.contains { flag in
            RoutineFlag.normalized(flag).map(configuredFlagIDs.contains) ?? false
        }
    }

    static func adding(
        _ kind: RoutineFlagRuleKind,
        for flag: String,
        in rules: [RoutineFlagRule]
    ) -> [RoutineFlagRule] {
        guard let cleanedFlag = RoutineFlag.cleaned(flag) else { return sanitized(rules) }
        return sanitized(rules + [RoutineFlagRule(flag: cleanedFlag, kind: kind)])
    }

    static func removing(
        _ kind: RoutineFlagRuleKind,
        for flag: String,
        from rules: [RoutineFlagRule]
    ) -> [RoutineFlagRule] {
        guard let normalizedFlag = RoutineFlag.normalized(flag) else { return sanitized(rules) }
        return sanitized(rules).filter {
            !($0.kind == kind && RoutineFlag.normalized($0.flag) == normalizedFlag)
        }
    }

    static func removing(_ flag: String, from rules: [RoutineFlagRule]) -> [RoutineFlagRule] {
        guard let normalizedFlag = RoutineFlag.normalized(flag) else { return sanitized(rules) }
        return sanitized(rules).filter { RoutineFlag.normalized($0.flag) != normalizedFlag }
    }
}

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
                  let normalizedTag = RoutineTag.normalized(cleanedTag) else {
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

        return sanitized(rules.map { rule in
            guard RoutineTag.contains(tag, in: [rule.tag]) else { return rule }
            return RoutineTagRule(tag: cleanedReplacement, kind: rule.kind)
        })
    }

    static func removing(_ tag: String, from rules: [RoutineTagRule]) -> [RoutineTagRule] {
        guard let normalizedTag = RoutineTag.normalized(tag) else { return sanitized(rules) }
        return sanitized(rules).filter { RoutineTag.normalized($0.tag) != normalizedTag }
    }
}

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

        if word.count > 4,
           (word.hasSuffix("xes") || word.hasSuffix("zes") || word.hasSuffix("ches") || word.hasSuffix("shes")) {
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
