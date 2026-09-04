import Foundation
import Testing

struct SettingsTagPresentationTests {
    @Test
    func tagCounterSettingsAreHiddenUntilATagExists() throws {
        let sourcePaths = [
            "iOS/Screens/Settings/SettingsTagsDetailView.swift",
            "RoutinaMacApp/Screens/Settings/SettingsMacTagsDetailView.swift"
        ]

        for sourcePath in sourcePaths {
            let source = try Self.sourceFile(sourcePath)

            #expect(source.contains("if !store.tags.savedTags.isEmpty {"))
            #expect(source.contains("Tag Counters"))
        }
    }

    @Test
    func savedTagOptionsAreRevealedOnlyForTheSelectedTag() throws {
        let source = try Self.sourceFile("iOS/Screens/Settings/SettingsTagsDetailView.swift")

        #expect(source.contains("@State private var selectedTagID: String?"))
        #expect(source.contains("isSelected: selectedTagID == tag.id"))
        #expect(source.contains("if isSelected {\n                tagOptions"))
        #expect(source.contains("selectedTagID = selectedTagID == tagID ? nil : tagID"))
        #expect(!source.contains("fastFilterButton"))
        #expect(!source.localizedCaseInsensitiveContains("quick filter"))
        #expect(source.contains(".frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)"))
        #expect(source.contains(".contentShape(.rect)"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
