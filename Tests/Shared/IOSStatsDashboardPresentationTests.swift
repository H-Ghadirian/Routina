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
