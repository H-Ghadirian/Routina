import AppKit
import SwiftUI
import WidgetKit

struct RoutinaMacRootScene: Scene {
    private let homeRoot: AnyView
    private let settingsRoot: AnyView
    private let persistence: PersistenceController

    @MainActor
    init() {
        let persistence = RoutinaAppSceneBootstrap.preparePersistence()
        self.persistence = persistence
        self.homeRoot = RoutinaMacSceneFactory.makeHomeRoot(persistence: persistence)
        self.settingsRoot = RoutinaMacSceneFactory.makeSettingsRoot(persistence: persistence)
    }

    var body: some Scene {
        WindowGroup(id: RoutinaMacSceneID.home) {
            homeRoot
                .background(RoutinaMacWindowRouterInstaller())
                .onAppear {
                    MacMenuCleanup.removeUnneededMenus()
                    DispatchQueue.main.async {
                        MacMenuCleanup.removeUnneededMenus()
                    }
                    WidgetStatsService.refresh(using: persistence.container)
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
                    WidgetStatsService.refresh(using: persistence.container)
                    WidgetCenter.shared.reloadAllTimelines()
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

        MenuBarExtra {
            RoutinaMacMenuBarContent()
        } label: {
            RoutinaMacMenuBarIcon()
        }

        Settings {
            settingsRoot
        }
    }
}

private enum RoutinaMacSceneID {
    static let home = "routina-home"
}

private struct RoutinaMacMenuBarContent: View {
    var body: some View {
        Group {
            Button("Add Task") {
                openHomeWindow()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(name: .routinaMacOpenAddTask, object: nil)
                }
            }

            Button("Open Routina") {
                openHomeWindow()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private func openHomeWindow() {
        RoutinaMacWindowRouter.shared.openHomeAndActivate()
    }
}

private struct RoutinaMacWindowRouterInstaller: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                RoutinaMacWindowRouter.shared.openHomeWindow = {
                    openWindow(id: RoutinaMacSceneID.home)
                }
            }
    }
}

private struct RoutinaMacMenuBarIcon: View {
    var body: some View {
        Image(systemName: "checklist.checked")
            .font(.system(size: 14, weight: .semibold))
    }
}
