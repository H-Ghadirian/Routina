import Foundation

struct HomeCustomTaskSection: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date? = Date()
    ) {
        self.id = id
        self.title = HomeCustomTaskSectionStorage.sanitizedTitle(title) ?? "Section"
        self.createdAt = createdAt
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
                    createdAt: section.createdAt
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

    private static func normalizedTitleKey(_ title: String) -> String {
        title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
