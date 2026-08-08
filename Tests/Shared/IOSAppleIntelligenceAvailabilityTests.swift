import Foundation
import Testing

struct IOSAppleIntelligenceAvailabilityTests {
    @Test
    func relationshipSuggestionsAreMacOnly() throws {
        let iosTaskDetail = try sourceFile("iOS/Screens/TaskDetail/TaskDetailTCAView.swift")
        let macTaskDetail = try sourceFile("RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift")
        let relationshipSection = try sourceFile(
            "SharedCore/Screens/TaskDetail/TaskDetailRelationshipsSectionView.swift"
        )

        #expect(iosTaskDetail.contains("showsAppleIntelligenceSuggestions: false"))
        #expect(macTaskDetail.contains("showsAppleIntelligenceSuggestions: true"))
        #expect(relationshipSection.contains("if showsAppleIntelligenceSuggestions {"))
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
