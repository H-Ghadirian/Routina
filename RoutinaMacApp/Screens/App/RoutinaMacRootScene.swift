import SwiftUI

struct RoutinaMacRootScene: Scene {
    private let homeRoot: AnyView
    private let settingsRoot: AnyView

    @MainActor
    init() {
        let persistence = RoutinaAppSceneBootstrap.preparePersistence()
        self.homeRoot = RoutinaMacSceneFactory.makeHomeRoot(persistence: persistence)
        self.settingsRoot = RoutinaMacSceneFactory.makeSettingsRoot(persistence: persistence)
    }

    var body: some Scene {
        WindowGroup {
            homeRoot
                .onAppear {
                    MacMenuCleanup.removeUnneededMenus()
                    DispatchQueue.main.async {
                        MacMenuCleanup.removeUnneededMenus()
                    }
                }
        }
        .defaultSize(
            width: RoutinaMacWindowSizing.defaultWidth,
            height: RoutinaMacWindowSizing.defaultHeight
        )
        .windowResizability(.contentMinSize)
        .commands {
            RoutineCommands()
        }

        Settings {
            settingsRoot
        }
    }
}
