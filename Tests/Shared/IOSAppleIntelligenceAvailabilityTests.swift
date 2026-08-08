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
        let relationshipPicker = try sourceFile("SharedCore/Views/TaskRelationshipsEditor.swift")

        #expect(!iosTaskDetail.contains("relationshipSuggestionsRequested"))
        #expect(macTaskDetail.contains("suggestionConfiguration: relationshipSuggestionConfiguration"))
        #expect(!relationshipSection.contains("Suggest"))
        #expect(relationshipPicker.contains("@State private var isShowingSuggestions = false"))
        #expect(relationshipPicker.contains("if !isShowingSuggestions"))
        #expect(relationshipPicker.contains("Finding relevant task relationships…"))
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
