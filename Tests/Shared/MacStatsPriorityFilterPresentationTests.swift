import Foundation
import Testing

struct MacStatsPriorityFilterPresentationTests {
    @Test
    func statsSidebarUsesSeparateImportanceAndUrgencySections() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarView.swift"
        )

        #expect(source.contains("HomeMacStatsImportanceFilterSection("))
        #expect(source.contains("HomeMacStatsUrgencyFilterSection("))
        #expect(!source.contains("HomeMacImportanceUrgencyDisclosureSection("))
    }

    @Test
    func separateSectionsOnlyUpdateTheirOwnThreshold() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarSections.swift"
        )

        #expect(source.contains("ImportanceUrgencyFilterCell.updatingMinimumImportance("))
        #expect(source.contains("ImportanceUrgencyFilterCell.updatingMinimumUrgency("))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
