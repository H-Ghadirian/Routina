import Foundation

struct SettingsContentCatalog: Decodable, Equatable {
    struct SectionContent: Decodable, Equatable {
        let id: String
        let title: String
        let searchAliases: [String]
        let searchDetailTerms: [String]
    }

    struct PlatformSections: Decodable, Equatable {
        let macOS: [SectionContent]
        let mobile: [SectionContent]
    }

    struct QuickAddContent: Decodable, Equatable {
        let examples: [SettingsQuickAddExample]
        let syntaxGroups: [SettingsQuickAddSyntaxGroup]
        let notes: [String]
    }

    let quickAdd: QuickAddContent
    let sections: PlatformSections

    static let shared = load()

    func section(for id: SettingsSectionID) -> SectionContent {
        guard let content = currentSections.first(where: { $0.id == id.rawValue }) else {
            preconditionFailure("Settings content is missing section \(id.rawValue).")
        }
        return content
    }

    static func decode(_ data: Data) throws -> SettingsContentCatalog {
        let catalog = try JSONDecoder().decode(SettingsContentCatalog.self, from: data)
        try catalog.validate()
        return catalog
    }

    private var currentSections: [SectionContent] {
        #if os(macOS)
            sections.macOS
        #else
            sections.mobile
        #endif
    }

    private static func load() -> SettingsContentCatalog {
        guard
            let resourceURL = resourceBundle.url(
                forResource: "SettingsContentCatalog",
                withExtension: "json"
            )
        else {
            preconditionFailure("SettingsContentCatalog.json is missing from the resource bundle.")
        }

        do {
            return try decode(Data(contentsOf: resourceURL))
        } catch {
            preconditionFailure("SettingsContentCatalog.json is invalid: \(error)")
        }
    }

    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
            Bundle.module
        #else
            Bundle.main
        #endif
    }

    private func validate() throws {
        let expectedSectionIDs = Set(SettingsSectionID.allCases.map(\.rawValue))
        for platformSections in [sections.macOS, sections.mobile] {
            let sectionIDs = platformSections.map(\.id)
            guard Set(sectionIDs).count == sectionIDs.count else {
                throw SettingsContentCatalogError.duplicateSectionID
            }
            guard Set(sectionIDs) == expectedSectionIDs else {
                throw SettingsContentCatalogError.incompleteSectionCatalog
            }
        }
        guard !quickAdd.examples.isEmpty,
            !quickAdd.syntaxGroups.isEmpty,
            !quickAdd.notes.isEmpty
        else {
            throw SettingsContentCatalogError.emptyQuickAddCatalog
        }
    }
}

enum SettingsContentCatalogError: Error {
    case duplicateSectionID
    case incompleteSectionCatalog
    case emptyQuickAddCatalog
}
