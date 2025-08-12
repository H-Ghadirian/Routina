import Foundation

enum FastFilterTags {
    static func decoded(from rawValue: String?) -> [String] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }

        return sanitized(decoded)
    }

    static func encoded(_ tags: [String]) -> String? {
        let sanitizedTags = sanitized(tags)
        guard !sanitizedTags.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(sanitizedTags) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func sanitized(_ tags: [String]) -> [String] {
        RoutineTag.deduplicated(tags)
    }

    static func toggling(_ tag: String, in tags: [String]) -> [String] {
        guard let cleanedTag = RoutineTag.cleaned(tag) else {
            return sanitized(tags)
        }

        if RoutineTag.contains(cleanedTag, in: tags) {
            return RoutineTag.removing(cleanedTag, from: tags)
        }

        return sanitized(tags + [cleanedTag])
    }
}
