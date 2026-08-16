import Foundation
import Testing

struct HomeBlockedStatusBadgeSourceTests {
    @Test
    func platformHomeRefreshesCacheRelationshipBlockingInRowSnapshots() throws {
        let sources = try [
            sourceFile("RoutinaMacApp/Features/Home/HomeFeature+Display.swift"),
            sourceFile("iOS/Features/Home/HomeFeature+Display.swift")
        ]

        for source in sources {
            #expect(source.contains("HomeDisplayFilterSupport.activeRelationshipBlockedTaskIDs("))
            #expect(source.contains("display.hasActiveRelationshipBlocker = relationshipBlockedTaskIDs.contains(task.id)"))
        }
    }

    @Test
    func macTodosModeKeepsBlockedStatusBadgesVisible() throws {
        let source = try sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift")
        let functionStart = try #require(
            source.range(of: "func statusBadge(\n        for task:")
        )
        let functionEnd = try #require(
            source.range(
                of: "func emptyStateView(",
                range: functionStart.upperBound..<source.endIndex
            )
        )
        let functionSource = String(source[functionStart.lowerBound..<functionEnd.lowerBound])

        #expect(functionSource.contains("!task.hasActiveRelationshipBlocker"))
        #expect(functionSource.contains("task.todoState != .blocked"))
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
