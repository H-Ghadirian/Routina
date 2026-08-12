import Foundation
import Testing

struct SettingsTagPresentationTests {
    @Test
    func savedTagOptionsAreRevealedOnlyForTheSelectedTag() throws {
        let source = try Self.sourceFile("iOS/Screens/Settings/SettingsTagsDetailView.swift")

        #expect(source.contains("@State private var selectedTagID: String?"))
        #expect(source.contains("isSelected: selectedTagID == tag.id"))
        #expect(source.contains("if isSelected {\n                tagOptions"))
        #expect(source.contains("selectedTagID = selectedTagID == tagID ? nil : tagID"))
        #expect(source.contains("fastFilterButton\n                tagActionsMenu"))
        #expect(source.contains("\"In quick filters\" : \"Add to quick filters\""))
        #expect(source.contains("Quick filters make this tag easier to reach when filtering tasks."))
        #expect(source.contains(".frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)"))
        #expect(source.contains(".contentShape(.rect)"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
