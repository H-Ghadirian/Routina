import Foundation

enum HomeCustomTaskSectionRule: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case plannedToday
    case plannedTomorrow
    case tracking

    var id: Self { self }

    var title: String {
        switch self {
        case .plannedToday:
            return "Planned today"
        case .plannedTomorrow:
            return "Planned tomorrow"
        case .tracking:
            return "Tracking entries"
        }
    }
}

struct HomeCustomTaskSectionRules: Codable, Equatable, Hashable, Sendable {
    var enabledRules: Set<HomeCustomTaskSectionRule>
    var tagNames: [String]

    init(
        enabledRules: Set<HomeCustomTaskSectionRule> = [],
        tagNames: [String] = []
    ) {
        self.enabledRules = enabledRules
        self.tagNames = Self.sanitizedTagNames(tagNames)
    }

    var isEmpty: Bool {
        enabledRules.isEmpty && tagNames.isEmpty
    }

    func contains(_ rule: HomeCustomTaskSectionRule) -> Bool {
        enabledRules.contains(rule)
    }

    func setting(_ rule: HomeCustomTaskSectionRule, enabled isEnabled: Bool) -> Self {
        var rules = enabledRules
        if isEnabled {
            rules.insert(rule)
        } else {
            rules.remove(rule)
        }
        return HomeCustomTaskSectionRules(enabledRules: rules, tagNames: tagNames)
    }

    func settingTagNames(_ rawTagNames: [String]) -> Self {
        HomeCustomTaskSectionRules(
            enabledRules: enabledRules,
            tagNames: rawTagNames
        )
    }

    func matchesTags(_ taskTags: [String]) -> Bool {
        tagNames.contains { tagName in
            RoutineTag.contains(tagName, in: taskTags)
        }
    }

    static func sanitizedTagNames(_ tagNames: [String]) -> [String] {
        RoutineTag.deduplicated(tagNames)
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValues = (try? container.decode([String].self, forKey: .enabled)) ?? []
        enabledRules = Set(rawValues.compactMap(HomeCustomTaskSectionRule.init(rawValue:)))
        tagNames = Self.sanitizedTagNames(
            (try? container.decode([String].self, forKey: .tags)) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let rawValues = HomeCustomTaskSectionRule.allCases
            .filter { enabledRules.contains($0) }
            .map(\.rawValue)
        try container.encode(rawValues, forKey: .enabled)
        try container.encode(tagNames, forKey: .tags)
    }
}

struct HomeCustomTaskSection: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date?
    var rules: HomeCustomTaskSectionRules

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date? = Date(),
        rules: HomeCustomTaskSectionRules = HomeCustomTaskSectionRules()
    ) {
        self.id = id
        self.title = HomeCustomTaskSectionStorage.sanitizedTitle(title) ?? "Section"
        self.createdAt = createdAt
        self.rules = rules
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case rules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = HomeCustomTaskSectionStorage.sanitizedTitle(
            try container.decode(String.self, forKey: .title)
        ) ?? "Section"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        rules = (try? container.decodeIfPresent(HomeCustomTaskSectionRules.self, forKey: .rules))
            ?? HomeCustomTaskSectionRules()
    }
}

enum HomeCustomTaskSectionStorage {
    private static let manualOrderSectionKeyPrefix = "customTaskSection:"
    private static let maxTitleLength = 48

    static func manualOrderSectionKey(for sectionID: UUID) -> String {
        "\(manualOrderSectionKeyPrefix)\(sectionID.uuidString.lowercased())"
    }

    static func sectionID(fromManualOrderSectionKey sectionKey: String) -> UUID? {
        guard sectionKey.hasPrefix(manualOrderSectionKeyPrefix) else { return nil }
        return UUID(uuidString: String(sectionKey.dropFirst(manualOrderSectionKeyPrefix.count)))
    }

    static func sanitizedTitle(_ rawTitle: String) -> String? {
        let words = rawTitle.split { $0.isWhitespace }
        let collapsed = words.joined(separator: " ")
        let trimmed = String(collapsed.prefix(maxTitleLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func decoded(from rawValue: String?) -> [HomeCustomTaskSection] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([HomeCustomTaskSection].self, from: data)
        else {
            return []
        }

        return sanitized(decoded)
    }

    static func encoded(_ sections: [HomeCustomTaskSection]) -> String {
        let sections = sanitized(sections)
        guard !sections.isEmpty,
              let data = try? JSONEncoder().encode(sections),
              let rawValue = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return rawValue
    }

    static func sanitized(_ sections: [HomeCustomTaskSection]) -> [HomeCustomTaskSection] {
        var seenIDs: Set<UUID> = []
        var seenTitleKeys: Set<String> = []
        var sanitizedSections: [HomeCustomTaskSection] = []

        for section in sections {
            guard seenIDs.insert(section.id).inserted,
                  let title = sanitizedTitle(section.title) else {
                continue
            }
            let titleKey = normalizedTitleKey(title)
            guard seenTitleKeys.insert(titleKey).inserted else { continue }
            sanitizedSections.append(
                HomeCustomTaskSection(
                    id: section.id,
                    title: title,
                    createdAt: section.createdAt,
                    rules: section.rules
                )
            )
        }

        return sanitizedSections
    }

    static func upsertingSection(
        title rawTitle: String,
        in sections: [HomeCustomTaskSection],
        now: Date = Date()
    ) -> (section: HomeCustomTaskSection, sections: [HomeCustomTaskSection])? {
        guard let title = sanitizedTitle(rawTitle) else { return nil }
        let sanitizedSections = sanitized(sections)
        let titleKey = normalizedTitleKey(title)

        if let existing = sanitizedSections.first(where: { normalizedTitleKey($0.title) == titleKey }) {
            return (existing, sanitizedSections)
        }

        let section = HomeCustomTaskSection(title: title, createdAt: now)
        return (section, sanitizedSections + [section])
    }

    static func deletingSection(
        _ sectionID: UUID,
        from sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection] {
        sanitized(sections).filter { $0.id != sectionID }
    }

    static func renamingSection(
        _ sectionID: UUID,
        title rawTitle: String,
        in sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection]? {
        guard let title = sanitizedTitle(rawTitle) else { return nil }

        var sanitizedSections = sanitized(sections)
        guard let sectionIndex = sanitizedSections.firstIndex(where: { $0.id == sectionID }) else {
            return nil
        }

        let titleKey = normalizedTitleKey(title)
        let titleBelongsToOtherSection = sanitizedSections.enumerated().contains { index, section in
            index != sectionIndex && normalizedTitleKey(section.title) == titleKey
        }
        guard !titleBelongsToOtherSection else { return nil }

        sanitizedSections[sectionIndex].title = title
        return sanitizedSections
    }

    static func settingRule(
        _ rule: HomeCustomTaskSectionRule,
        isEnabled: Bool,
        for sectionID: UUID,
        in sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection]? {
        var sanitizedSections = sanitized(sections)
        guard let sectionIndex = sanitizedSections.firstIndex(where: { $0.id == sectionID }) else {
            return nil
        }

        sanitizedSections[sectionIndex].rules = sanitizedSections[sectionIndex].rules
            .setting(rule, enabled: isEnabled)
        return sanitizedSections
    }

    static func settingTagNames(
        _ tagNames: [String],
        for sectionID: UUID,
        in sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection]? {
        var sanitizedSections = sanitized(sections)
        guard let sectionIndex = sanitizedSections.firstIndex(where: { $0.id == sectionID }) else {
            return nil
        }

        sanitizedSections[sectionIndex].rules = sanitizedSections[sectionIndex].rules
            .settingTagNames(tagNames)
        return sanitizedSections
    }

    private static func normalizedTitleKey(_ title: String) -> String {
        title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
