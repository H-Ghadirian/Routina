import Foundation

struct SettingsQuickAddExample: Decodable, Identifiable, Equatable {
    var phrase: String
    var result: String

    var id: String { phrase }
}

struct SettingsQuickAddSyntaxGroup: Decodable, Identifiable, Equatable {
    var title: String
    var rows: [SettingsQuickAddSyntaxItem]

    var id: String { title }
}

struct SettingsQuickAddSyntaxItem: Decodable, Identifiable, Equatable {
    var syntax: String
    var detail: String

    var id: String { syntax }
}

enum SettingsQuickAddSyntaxGuide {
    private static let content = SettingsContentCatalog.shared.quickAdd

    static var examples: [SettingsQuickAddExample] {
        content.examples
    }

    static var syntaxGroups: [SettingsQuickAddSyntaxGroup] {
        content.syntaxGroups
    }

    static var notes: [String] {
        content.notes
    }

    static func visibleExamples(includingPlaces: Bool) -> [SettingsQuickAddExample] {
        guard !includingPlaces else { return examples }

        return examples.filter { example in
            !example.phrase.contains("@")
        }
    }

    static func visibleSyntaxGroups(includingPlaces: Bool) -> [SettingsQuickAddSyntaxGroup] {
        guard !includingPlaces else { return syntaxGroups }

        return syntaxGroups.map { group in
            SettingsQuickAddSyntaxGroup(
                title: group.title,
                rows: group.rows.filter { !$0.syntax.contains("@") }
            )
        }
    }

    static func visibleNotes(includingPlaces: Bool) -> [String] {
        guard !includingPlaces else { return notes }

        return notes.map { note in
            note.replacingOccurrences(of: "Tags and places stop at spaces", with: "Tags stop at spaces")
        }
    }
}
