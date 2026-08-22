import Foundation
import Testing

struct MacWorkspaceNavigationSourceTests {
    @Test
    func backlogAndTaskLadderAreMainWindowWorkspaces() throws {
        let appFeatureSource = try Self.sourceFile(
            "RoutinaMacApp/Features/App/AppFeature.swift"
        )
        let homeFeatureSource = try Self.sourceFile(
            "RoutinaMacApp/Features/Home/HomeFeature.swift"
        )
        let sceneSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift"
        )
        let platformSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift"
        )
        let toolbarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacHomeToolbarContent.swift"
        )
        let controlsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacSidebarModeStripView.swift"
        )
        let commandSource = try Self.sourceFile(
            "RoutinaMacApp/Commands/RoutineCommands.swift"
        )

        #expect(appFeatureSource.contains("var backlog = BacklogFeature.State()"))
        #expect(appFeatureSource.contains("var taskRanking = TaskRankingFeature.State()"))
        #expect(homeFeatureSource.contains("case backlog = \"Backlog\""))
        #expect(homeFeatureSource.contains("case taskLadder = \"Task Ladder\""))
        #expect(homeFeatureSource.contains("static let workspaceModes: [Self]"))
        #expect(!sceneSource.contains("Window(\"Backlog\""))
        #expect(!sceneSource.contains("Window(\"Task Ladder\""))
        #expect(platformSource.contains("BacklogMacView(store: backlogStore)"))
        #expect(platformSource.contains("TaskRankingMacView(store: taskRankingStore)"))
        #expect(toolbarSource.contains("HomeMacWorkspaceToolbarControls("))
        #expect(controlsSource.contains("private var workspaceMenu: some View"))
        #expect(controlsSource.contains("private var addControl: some View"))
        #expect(controlsSource.contains("Button(action: onOpenSettings)"))
        #expect(commandSource.contains("openWindow(id: RoutinaMacSceneID.home)"))
        #expect(commandSource.contains(".routinaMacOpenBacklogInMainWindow"))
        #expect(commandSource.contains(".routinaMacOpenTaskLadderInMainWindow"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
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
