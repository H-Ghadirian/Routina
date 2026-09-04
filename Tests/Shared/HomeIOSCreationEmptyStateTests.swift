import Foundation
import Testing

struct HomeIOSCreationEmptyStateTests {
    @Test
    func emptyAndNoMatchStatesOfferTheRightSmartAddEntryPoint() throws {
        let home = try sourceFile("iOS/Screens/Home/HomeTCAView.swift")
        let platform = try sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let toolbar = try sourceFile("iOS/Screens/Home/HomeIOSHomeToolbarContent.swift")
        let rootScene = try sourceFile("iOS/App/RoutinaIOSRootScene.swift")
        let emptyState = try sourceFile("SharedCore/Screens/Home/HomeStatusAndEmptyViews.swift")
        let snapshot = try sourceFile("SharedCore/Features/Home/HomeIOSPresentationSnapshot.swift")

        #expect(platform.contains("title: \"What would you like to get done?\""))
        #expect(platform.contains("actionTitle: \"Create Your First Task\""))
        #expect(platform.contains("&& !hasCompletedFirstTaskExperience"))
        #expect(platform.contains("showFilters: !isFirstTaskExperiencePending"))
        #expect(toolbar.contains("if showFilters"))
        #expect(rootScene.contains("IOSFirstTaskExperience.prepareForLaunch("))
        #expect(rootScene.contains("DeviceActivityRecorder.hasExistingInstallationID()"))
        #expect(platform.contains("actionTitle: \"Add New Task\""))
        #expect(platform.contains("actionTitle: \"Create Task\""))
        #expect(platform.contains("action: searchTaskCreationText == nil ? nil : { openAddTask() }"))
        #expect(home.contains("searchTaskCreationText = result.searchTaskCreationText"))
        #expect(snapshot.contains("if !containsKnownTask"))
        #expect(snapshot.contains("searchTaskCreationText: searchSeed"))
        #expect(home.contains("IOSSmartAddTaskSheet(homeStore: store, initialText: smartAddSeedText)"))
        #expect(home.contains("_text = State(initialValue: initialText)"))
        #expect(emptyState.contains("if let action {\n                Button(actionTitle, action: action)"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
