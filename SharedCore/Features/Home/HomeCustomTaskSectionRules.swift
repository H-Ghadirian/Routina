import Foundation

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
        tagMatchMode =
            (try? container.decode(
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
