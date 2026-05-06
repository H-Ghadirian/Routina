import AppKit
import SwiftUI
import SwiftData
import WidgetKit

struct RoutinaMacRootScene: Scene {
    private let homeRoot: AnyView
    private let settingsRoot: AnyView
    private let persistence: PersistenceController
    private let focusTimerStatusStore: RoutinaMacFocusTimerStatusStore

    @MainActor
    init() {
        let persistence = RoutinaAppSceneBootstrap.preparePersistence()
        let homeRoot = RoutinaMacSceneFactory.makeHomeRoot(persistence: persistence)
        self.persistence = persistence
        self.homeRoot = homeRoot
        self.settingsRoot = RoutinaMacSceneFactory.makeSettingsRoot(persistence: persistence)
        self.focusTimerStatusStore = RoutinaMacFocusTimerStatusStore(persistence: persistence)
        RoutinaMacFocusTimerStatusBarController.shared.configure(store: focusTimerStatusStore)
        RoutinaMacWindowRouter.shared.installFallbackHomeWindowOpener {
            RoutinaMacFallbackHomeWindowPresenter.shared.showHomeWindow(rootView: homeRoot)
        }
    }

    var body: some Scene {
        WindowGroup("Routina", id: RoutinaMacSceneID.home) {
            homeRoot
                .background(RoutinaMacWindowRouterInstaller())
                .onAppear {
                    MacMenuCleanup.removeUnneededMenus()
                    DispatchQueue.main.async {
                        MacMenuCleanup.removeUnneededMenus()
                    }
                    refreshWidgetStats()
                    focusTimerStatusStore.refresh()
                    activateHomeWindow()
                }
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                    refreshWidgetStats()
                    focusTimerStatusStore.refresh()
                }
                .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
                    focusTimerStatusStore.refresh()
                }
        }
        .defaultSize(
            width: RoutinaMacWindowSizing.defaultWidth,
            height: RoutinaMacWindowSizing.defaultHeight
        )
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.presented)
        .commands {
            RoutineCommands()
        }

        Settings {
            settingsRoot
        }
    }

    @MainActor
    private func refreshWidgetStats() {
        WidgetStatsService.refresh(using: persistence.container)
        FocusTimerWidgetService.refresh(using: persistence.container)
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor
    private func activateHomeWindow() {
        RoutinaMacWindowRouter.shared.activateHomeWindow()
    }
}

private enum RoutinaMacSceneID {
    static let home = "routina-home"
}

private struct RoutinaMacWindowRouterInstaller: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                RoutinaMacWindowRouter.shared.installHomeWindowOpener {
                    openWindow(id: RoutinaMacSceneID.home)
                }
            }
    }
}

@MainActor
private final class RoutinaMacFallbackHomeWindowPresenter {
    static let shared = RoutinaMacFallbackHomeWindowPresenter()

    private var window: NSWindow?

    private init() {}

    func showHomeWindow(rootView: AnyView) {
        if let window {
            show(window)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: RoutinaMacWindowSizing.defaultWidth,
                height: RoutinaMacWindowSizing.defaultHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Routina"
        window.minSize = NSSize(
            width: RoutinaMacWindowSizing.minWidth,
            height: RoutinaMacWindowSizing.minHeight
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        self.window = window
        show(window)
    }

    private func show(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        window.deminiaturize(nil)
        window.level = .normal
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        NSApp.activate(ignoringOtherApps: true)
    }
}
