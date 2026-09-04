import Foundation
import Testing

struct MacSettingsWindowPresentationTests {
    @Test
    func settingsUsesAStandardFullscreenWindowAndKeepsSystemRouting() throws {
        let scene = try Self.sourceFile(
            "RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift"
        )
        let commands = try Self.sourceFile(
            "RoutinaMacApp/Commands/RoutineCommands.swift"
        )

        #expect(
            scene.contains(
                "Window(\"Routinam Settings\", id: RoutinaMacSceneID.settings)"
            )
        )
        #expect(scene.contains(".windowResizability(.contentMinSize)"))
        #expect(scene.contains(".defaultLaunchBehavior(.suppressed)"))
        #expect(!scene.contains("Settings {"))
        #expect(!scene.contains("RoutinaMacSettingsWindowConfigurator"))

        #expect(commands.contains("CommandGroup(replacing: .appSettings)"))
        #expect(commands.contains("openWindow(id: RoutinaMacSceneID.settings)"))
        #expect(commands.contains(".keyboardShortcut(\",\", modifiers: .command)"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
