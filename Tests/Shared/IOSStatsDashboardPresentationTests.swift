import Foundation
import Testing

struct IOSStatsDashboardPresentationTests {
    @Test
    func secondaryComparisonReportsAreUnavailableOnIOS() throws {
        let source = try sourceFile("iOS/Screens/Stats/StatsDashboardSupport.swift")

        #expect(
            source.contains(
                "case .unassignedFocus, .focusWorkChart, .estimateActual:\n            return false"
            )
        )
    }

    @Test
    func focus2048OmitsSupplementaryDetailsOnIOS() throws {
        let iOSStatsSource = try sourceFile("iOS/Screens/Stats/StatsView.swift")
        let focus2048Source = try sourceFile("SharedCore/Views/StatsFocus2048Section.swift")

        let focus2048Section = try #require(
            iOSStatsSource.components(
                separatedBy: "private func focus2048Section(metrics: Metrics) -> some View {"
            ).dropFirst().first
        )

        #expect(focus2048Section.contains("showsSupplementaryDetails: false"))
        #expect(
            focus2048Source.components(separatedBy: "if showsSupplementaryDetails {").count == 4
        )
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
