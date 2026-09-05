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
                let normalizedHex = normalizedHex(entry.value)
            else {
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
            let normalizedReplacement = RoutineTag.normalized(replacement)
        else {
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
            withoutPrefix.allSatisfy({ $0.isHexDigit })
        else {
            return nil
        }
        return "#\(withoutPrefix.uppercased())"
    }
}
