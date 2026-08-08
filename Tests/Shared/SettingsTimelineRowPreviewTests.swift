import Foundation
import Testing

struct SettingsTimelineRowPreviewTests {
    @Test
    func previewUsesTheTimelineRowsFixedSurfacesAndVisibleFields() throws {
        let source = try sourceFile("SharedCore/Views/SettingsTimelineRowPreviewView.swift")

        #expect(source.contains("Yesterday · Completed task"))
        #expect(source.contains("routinaScrollingRoundedFill"))
        #expect(source.contains("routinaScrollingPillFill"))
        #expect(!source.contains("routinaGlassCard"))
        #expect(!source.contains("routinaGlassPill"))
    }

    @Test
    func timelineAppearanceSettingsDoNotShowAFieldCountSummary() throws {
        let source = try sourceFile("iOS/Screens/Settings/SettingsAppearanceDetailView.swift")

        #expect(!source.contains("timelineRowVisibility.summaryText"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
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
