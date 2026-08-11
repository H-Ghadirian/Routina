import Foundation
import Testing

struct HomeIOSCreationEmptyStateTests {
    @Test
    func emptyAndNoMatchStatesOfferTheRightSmartAddEntryPoint() throws {
        let home = try sourceFile("iOS/Screens/Home/HomeTCAView.swift")
        let platform = try sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let emptyState = try sourceFile("SharedCore/Screens/Home/HomeStatusAndEmptyViews.swift")

        #expect(platform.contains("actionTitle: \"Add New Task\""))
        #expect(platform.contains("actionTitle: \"Create Task\""))
        #expect(platform.contains("action: searchTaskCreationText == nil ? nil : { openAddTask() }"))
        #expect(home.contains("searchTaskCreationText = smartAddSeedText.isEmpty"))
        #expect(home.contains("knownTaskSearchSourceDisplays.contains(where: filtering.matchesSearch)"))
        #expect(home.contains("IOSSmartAddTaskSheet(homeStore: store, initialText: smartAddSeedText)"))
        #expect(home.contains("_text = State(initialValue: initialText)"))
        #expect(emptyState.contains("if let action {\n                Button(actionTitle, action: action)"))
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
