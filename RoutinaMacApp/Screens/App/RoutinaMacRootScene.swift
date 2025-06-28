import SwiftUI

struct RoutinaMacRootScene: Scene {
    private let homeRoot: AnyView
    private let statsRoot: AnyView
    private let settingsRoot: AnyView

    @MainActor
    init() {
        let persistence = RoutinaAppSceneBootstrap.preparePersistence()
        self.homeRoot = RoutinaMacSceneFactory.makeHomeRoot(persistence: persistence)
        self.statsRoot = RoutinaMacSceneFactory.makeStatsRoot(persistence: persistence)
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

        Window("Stats", id: RoutinaMacWindowID.stats) {
            statsRoot
        }
        .defaultSize(
            width: RoutinaMacStatsSizing.defaultWidth,
            height: RoutinaMacStatsSizing.defaultHeight
        )
        .windowResizability(.contentMinSize)

        Settings {
            settingsRoot
        }
    }
}
