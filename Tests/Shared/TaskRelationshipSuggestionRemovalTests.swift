import Foundation
import Testing

struct TaskRelationshipSuggestionRemovalTests {
    @Test
    func taskRelationshipsRemainManualAcrossPlatforms() throws {
        let macTaskDetail = try sourceFile("RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift")
        let relationshipPicker = try sourceFile("SharedCore/Views/TaskRelationshipsEditor.swift")
        let commands = try sourceFile("RoutinaMacApp/Commands/RoutineCommands.swift")
        let rootScene = try sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")

        #expect(!macTaskDetail.contains("relationshipSuggestion"))
        #expect(!relationshipPicker.contains("TaskRelationshipSuggestion"))
        #expect(!relationshipPicker.contains("Suggested relationships"))
        #expect(!commands.contains("Review Task Relationships"))
        #expect(!rootScene.contains("taskRelationshipReview"))
        #expect(relationshipPicker.contains("TaskRelationshipKindMenuPicker(selection: $selectedKind)"))
        #expect(relationshipPicker.contains("Button(\"Add Relationship\")"))
        #expect(relationshipPicker.contains("TaskRelationshipActionPresentation.createTaskTitle"))
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
