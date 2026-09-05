import Foundation

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

    /// Keeps Mac-only behavior markers out of iOS presentation without
    /// deleting assignments that may have synchronized from a Mac.
    static func iOSVisible(_ flags: [String]) -> [String] {
        flags.filter { flag in
            !contains(
                RoutineFlagRuleKind.hideFromCalendarList.builtInFlagName,
                in: [flag]
            )
        }
    }

    static func iOSVisible(_ flags: Set<String>) -> Set<String> {
        Set(iOSVisible(Array(flags)))
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

    /// Rules whose behavior can be understood and observed entirely on iOS.
    /// The complete built-in catalog remains persisted for Mac and sync.
    static var iOSVisibleCases: [Self] {
        allCases.filter { $0 != .hideFromCalendarList }
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
                let normalizedFlag = RoutineFlag.normalized(cleanedFlag)
            else {
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
