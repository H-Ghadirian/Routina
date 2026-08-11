import Foundation

/// A custom path either keeps a task in the everyday sidebar or moves it to
/// the separate Backlog workspace.  This is stored on the section rather than
/// each task so a subsection always follows its parent workspace.
enum HomeTaskSectionSurface: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case radar
    case backlog
}

struct HomeCustomTaskSectionRules: Codable, Equatable, Hashable, Sendable {
    var tagNames: [String]
    var tagMatchMode: RoutineTagMatchMode

    init(
        tagNames: [String] = [],
        tagMatchMode: RoutineTagMatchMode = .any
    ) {
        self.tagNames = Self.sanitizedTagNames(tagNames)
        self.tagMatchMode = tagMatchMode
    }

    var isEmpty: Bool {
        tagNames.isEmpty
    }

    func settingTagNames(_ rawTagNames: [String]) -> Self {
        HomeCustomTaskSectionRules(
            tagNames: rawTagNames,
            tagMatchMode: tagMatchMode
        )
    }

    func settingTagMatchMode(_ tagMatchMode: RoutineTagMatchMode) -> Self {
        HomeCustomTaskSectionRules(
            tagNames: tagNames,
            tagMatchMode: tagMatchMode
        )
    }

    func matchesTags(_ taskTags: [String]) -> Bool {
        guard !tagNames.isEmpty else { return false }

        switch tagMatchMode {
        case .any:
            return tagNames.contains { tagName in
                RoutineTag.contains(tagName, in: taskTags)
            }
        case .all:
            return tagNames.allSatisfy { tagName in
                RoutineTag.contains(tagName, in: taskTags)
            }
        }
    }

    static func sanitizedTagNames(_ tagNames: [String]) -> [String] {
        RoutineTag.deduplicated(tagNames)
    }

    private enum CodingKeys: String, CodingKey {
        case tags
        case tagMatchMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagNames = Self.sanitizedTagNames(
            (try? container.decode([String].self, forKey: .tags)) ?? []
        )
        tagMatchMode = (try? container.decode(
            RoutineTagMatchMode.self,
            forKey: .tagMatchMode
        )) ?? .any
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tagNames, forKey: .tags)
        try container.encode(tagMatchMode, forKey: .tagMatchMode)
    }
}

struct HomeCustomTaskSectionDraftState: Equatable, Sendable {
    var titleDrafts: [UUID: String] = [:]
    var tagRuleDrafts: [UUID: String] = [:]

    private var syncedTitles: [UUID: String] = [:]
    private var syncedTagRuleDrafts: [UUID: String] = [:]

    mutating func sync(with sections: [HomeCustomTaskSection]) {
        let validSectionIDs = Set(sections.map(\.id))
        titleDrafts = titleDrafts.filter { validSectionIDs.contains($0.key) }
        tagRuleDrafts = tagRuleDrafts.filter { validSectionIDs.contains($0.key) }

        var updatedSyncedTitles: [UUID: String] = [:]
        var updatedSyncedTagRuleDrafts: [UUID: String] = [:]

        for section in sections {
            let tagRuleText = section.rules.tagNames.joined(separator: ", ")

            if titleDrafts[section.id] == nil
                || titleDrafts[section.id] == syncedTitles[section.id] {
                titleDrafts[section.id] = section.title
            }
            if tagRuleDrafts[section.id] == nil
                || tagRuleDrafts[section.id] == syncedTagRuleDrafts[section.id] {
                tagRuleDrafts[section.id] = tagRuleText
            }

            updatedSyncedTitles[section.id] = section.title
            updatedSyncedTagRuleDrafts[section.id] = tagRuleText
        }

        syncedTitles = updatedSyncedTitles
        syncedTagRuleDrafts = updatedSyncedTagRuleDrafts
    }
}

struct HomeCustomTaskSection: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var parentSectionID: UUID?
    var surface: HomeTaskSectionSurface
    var title: String
    var createdAt: Date?
    var rules: HomeCustomTaskSectionRules
    var colorHex: String?
    /// Super sections retain the exact tasks they paused so resuming the section
    /// never resumes a task that had already been paused independently.
    var pausedAt: Date?
    var pausedTaskIDs: [UUID]

    init(
        id: UUID = UUID(),
        parentSectionID: UUID? = nil,
        surface: HomeTaskSectionSurface = .radar,
        title: String,
        createdAt: Date? = Date(),
        rules: HomeCustomTaskSectionRules = HomeCustomTaskSectionRules(),
        colorHex: String? = nil,
        pausedAt: Date? = nil,
        pausedTaskIDs: [UUID] = []
    ) {
        self.id = id
        self.parentSectionID = parentSectionID
        self.surface = surface
        self.title = HomeCustomTaskSectionStorage.sanitizedTitle(title) ?? "Section"
        self.createdAt = createdAt
        self.rules = rules
        self.colorHex = HomeCustomTaskSectionStorage.sanitizedColorHex(colorHex)
        self.pausedAt = parentSectionID == nil ? pausedAt : nil
        self.pausedTaskIDs = parentSectionID == nil
            ? HomeCustomTaskSectionStorage.deduplicatedTaskIDs(pausedTaskIDs)
            : []
    }

    var isPaused: Bool {
        pausedAt != nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case parentSectionID
        case surface
        case title
        case createdAt
        case rules
        case colorHex
        case pausedAt
        case pausedTaskIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        parentSectionID = try container.decodeIfPresent(UUID.self, forKey: .parentSectionID)
        surface = try container.decodeIfPresent(HomeTaskSectionSurface.self, forKey: .surface) ?? .radar
        title = HomeCustomTaskSectionStorage.sanitizedTitle(
            try container.decode(String.self, forKey: .title)
        ) ?? "Section"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        rules = (try? container.decodeIfPresent(HomeCustomTaskSectionRules.self, forKey: .rules))
            ?? HomeCustomTaskSectionRules()
        colorHex = HomeCustomTaskSectionStorage.sanitizedColorHex(
            try? container.decodeIfPresent(String.self, forKey: .colorHex)
        )
        pausedAt = parentSectionID == nil
            ? try? container.decodeIfPresent(Date.self, forKey: .pausedAt)
            : nil
        pausedTaskIDs = parentSectionID == nil
            ? HomeCustomTaskSectionStorage.deduplicatedTaskIDs(
                (try? container.decodeIfPresent([UUID].self, forKey: .pausedTaskIDs)) ?? []
            )
            : []
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

    static func sanitizedColorHex(_ colorHex: String?) -> String? {
        guard let colorHex else { return nil }
        return RoutineTagColors.sanitized(["section": colorHex])["section"]
    }

    static func deduplicatedTaskIDs(_ taskIDs: [UUID]) -> [UUID] {
        var seenTaskIDs: Set<UUID> = []
        return taskIDs.filter { seenTaskIDs.insert($0).inserted }
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
        var seenTitleKeysByParent: [UUID?: Set<String>] = [:]
        var sanitizedSections: [HomeCustomTaskSection] = []
        let candidateTopLevelSections = sections.reduce(into: [UUID: HomeTaskSectionSurface]()) {
            partialResult,
            section in
            guard section.parentSectionID == nil,
                  partialResult[section.id] == nil else {
                return
            }
            partialResult[section.id] = section.surface
        }

        for section in sections {
            guard seenIDs.insert(section.id).inserted,
                  let title = sanitizedTitle(section.title) else {
                continue
            }
            let parentSectionID = section.parentSectionID.flatMap {
                candidateTopLevelSections[$0] == nil || $0 == section.id ? nil : $0
            }
            let surface = parentSectionID.flatMap { candidateTopLevelSections[$0] } ?? section.surface
            let titleKey = normalizedTitleKey(title)
            var siblingTitleKeys = seenTitleKeysByParent[parentSectionID] ?? []
            guard siblingTitleKeys.insert(titleKey).inserted else { continue }
            seenTitleKeysByParent[parentSectionID] = siblingTitleKeys
            sanitizedSections.append(
                HomeCustomTaskSection(
                    id: section.id,
                    parentSectionID: parentSectionID,
                    surface: surface,
                    title: title,
                    createdAt: section.createdAt,
                    rules: section.rules,
                    colorHex: section.colorHex,
                    pausedAt: parentSectionID == nil ? section.pausedAt : nil,
                    pausedTaskIDs: parentSectionID == nil ? section.pausedTaskIDs : []
                )
            )
        }

        return sanitizedSections
    }

    static func upsertingSection(
        title rawTitle: String,
        parentSectionID: UUID? = nil,
        surface: HomeTaskSectionSurface = .radar,
        in sections: [HomeCustomTaskSection],
        now: Date = Date()
    ) -> (section: HomeCustomTaskSection, sections: [HomeCustomTaskSection])? {
        guard let title = sanitizedTitle(rawTitle) else { return nil }
        let sanitizedSections = sanitized(sections)
        let resolvedSurface: HomeTaskSectionSurface
        if let parentSectionID {
            guard let parent = sanitizedSections.first(where: {
                $0.id == parentSectionID && $0.parentSectionID == nil
            }) else {
                return nil
            }
            resolvedSurface = parent.surface
        } else {
            resolvedSurface = surface
        }
        let titleKey = normalizedTitleKey(title)

        if let existing = sanitizedSections.first(where: {
            $0.parentSectionID == parentSectionID && normalizedTitleKey($0.title) == titleKey
        }) {
            return (existing, sanitizedSections)
        }

        let section = HomeCustomTaskSection(
            parentSectionID: parentSectionID,
            surface: resolvedSurface,
            title: title,
            createdAt: now
        )
        return (section, sanitizedSections + [section])
    }

    static func deletingSection(
        _ sectionID: UUID,
        from sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection] {
        sanitized(sections).filter {
            $0.id != sectionID && $0.parentSectionID != sectionID
        }
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
        let parentSectionID = sanitizedSections[sectionIndex].parentSectionID
        let titleBelongsToOtherSection = sanitizedSections.enumerated().contains { index, section in
            index != sectionIndex
                && section.parentSectionID == parentSectionID
                && normalizedTitleKey(section.title) == titleKey
        }
        guard !titleBelongsToOtherSection else { return nil }

        sanitizedSections[sectionIndex].title = title
        return sanitizedSections
    }

    static func movingSection(
        _ sectionID: UUID,
        by offset: Int,
        in sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection]? {
        guard offset == -1 || offset == 1 else { return nil }

        var sanitizedSections = sanitized(sections)
        guard let sectionIndex = sanitizedSections.firstIndex(where: { $0.id == sectionID }) else {
            return nil
        }

        let parentSectionID = sanitizedSections[sectionIndex].parentSectionID
        let siblingIndices = sanitizedSections.indices.filter {
            sanitizedSections[$0].parentSectionID == parentSectionID
        }
        guard let siblingPosition = siblingIndices.firstIndex(of: sectionIndex) else {
            return nil
        }

        let destinationPosition = siblingPosition + offset
        guard siblingIndices.indices.contains(destinationPosition) else { return nil }

        sanitizedSections.swapAt(sectionIndex, siblingIndices[destinationPosition])
        return sanitizedSections
    }

    static func settingColor(
        _ colorHex: String?,
        for sectionID: UUID,
        in sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection]? {
        var sanitizedSections = sanitized(sections)
        guard let sectionIndex = sanitizedSections.firstIndex(where: { $0.id == sectionID }) else {
            return nil
        }

        sanitizedSections[sectionIndex].colorHex = sanitizedColorHex(colorHex)
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

    static func settingTagMatchMode(
        _ tagMatchMode: RoutineTagMatchMode,
        for sectionID: UUID,
        in sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection]? {
        var sanitizedSections = sanitized(sections)
        guard let sectionIndex = sanitizedSections.firstIndex(where: { $0.id == sectionID }) else {
            return nil
        }

        sanitizedSections[sectionIndex].rules = sanitizedSections[sectionIndex].rules
            .settingTagMatchMode(tagMatchMode)
        return sanitizedSections
    }

    static func pausingSuperSection(
        _ sectionID: UUID,
        taskIDs: [UUID],
        at pauseDate: Date,
        in sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection]? {
        var sanitizedSections = sanitized(sections)
        guard let sectionIndex = sanitizedSections.firstIndex(where: {
            $0.id == sectionID && $0.parentSectionID == nil
        }), !sanitizedSections[sectionIndex].isPaused else {
            return nil
        }

        sanitizedSections[sectionIndex].pausedAt = pauseDate
        sanitizedSections[sectionIndex].pausedTaskIDs = deduplicatedTaskIDs(taskIDs)
        return sanitizedSections
    }

    static func resumingSuperSection(
        _ sectionID: UUID,
        in sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection]? {
        var sanitizedSections = sanitized(sections)
        guard let sectionIndex = sanitizedSections.firstIndex(where: {
            $0.id == sectionID && $0.parentSectionID == nil
        }), sanitizedSections[sectionIndex].isPaused else {
            return nil
        }

        sanitizedSections[sectionIndex].pausedAt = nil
        sanitizedSections[sectionIndex].pausedTaskIDs = []
        return sanitizedSections
    }

    static func topLevelSections(
        in sections: [HomeCustomTaskSection],
        surface: HomeTaskSectionSurface? = nil
    ) -> [HomeCustomTaskSection] {
        sanitized(sections).filter {
            $0.parentSectionID == nil && (surface == nil || $0.surface == surface)
        }
    }

    static func subsections(
        of parentSectionID: UUID,
        in sections: [HomeCustomTaskSection]
    ) -> [HomeCustomTaskSection] {
        sanitized(sections).filter { $0.parentSectionID == parentSectionID }
    }

    static func sectionAndDescendantIDs(
        for sectionID: UUID,
        in sections: [HomeCustomTaskSection]
    ) -> Set<UUID> {
        let sanitizedSections = sanitized(sections)
        return Set(
            sanitizedSections
                .filter { $0.id == sectionID || $0.parentSectionID == sectionID }
                .map(\.id)
        )
    }

    static func pathTitles(
        for sectionID: UUID,
        in sections: [HomeCustomTaskSection]
    ) -> [String]? {
        let sanitizedSections = sanitized(sections)
        guard let section = sanitizedSections.first(where: { $0.id == sectionID }) else {
            return nil
        }
        guard let parentSectionID = section.parentSectionID else {
            return [section.title]
        }
        guard let parent = sanitizedSections.first(where: {
            $0.id == parentSectionID && $0.parentSectionID == nil
        }) else {
            return nil
        }
        return [parent.title, section.title]
    }

    private static func normalizedTitleKey(_ title: String) -> String {
        title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
