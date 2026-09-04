import Foundation
import Testing

struct HomeIOSSectionHeaderContrastTests {
    @Test
    func collapsibleSectionCountUsesReadableSecondaryContrast() throws {
        let source = try Self.sourceFile("iOS/Screens/Home/HomeIOSTaskListView.swift")
        let headerStart = try #require(
            source.range(
                of: "private func sectionHeader("
            )
        )
        let headerEnd = try #require(
            source.range(
                of: "private func isSectionExpanded(",
                range: headerStart.upperBound..<source.endIndex
            )
        )
        let headerSource = String(source[headerStart.lowerBound..<headerEnd.lowerBound])

        #expect(headerSource.contains("Text(\"\\(section.tasks.count)\")"))
        #expect(headerSource.contains(".foregroundStyle(.secondary)"))
        #expect(!headerSource.contains(".foregroundStyle(.tertiary)"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
