import AppKit
import SwiftUI
import SwiftData
import WidgetKit

struct RoutinaMacRootScene: Scene {
    private let homeRoot: AnyView
    private let settingsRoot: AnyView
    private let focusTimerStatusStore: RoutinaMacFocusTimerStatusStore
    private let widgetRefreshScheduler: RoutinaMacWidgetRefreshScheduler

    @MainActor
    init() {
        let persistence = RoutinaAppSceneBootstrap.preparePersistence()
        let focusTimerStatusStore = RoutinaMacFocusTimerStatusStore(persistence: persistence)
        let homeRoot = RoutinaMacSceneFactory.makeHomeRoot(persistence: persistence)
        self.homeRoot = homeRoot
        self.settingsRoot = RoutinaMacSceneFactory.makeSettingsRoot(persistence: persistence)
        self.focusTimerStatusStore = focusTimerStatusStore
        self.widgetRefreshScheduler = RoutinaMacWidgetRefreshScheduler(persistence: persistence)
        RoutinaMacFocusTimerStatusBarController.shared.configure(store: focusTimerStatusStore)
        RoutinaMacWindowRouter.shared.installFallbackHomeWindowOpener {
            RoutinaMacFallbackHomeWindowPresenter.shared.showHomeWindow(
                rootView: AnyView(
                    homeRoot.environment(\.routinaMacFocusTimerStatusStore, focusTimerStatusStore)
                )
            )
        }
    }

    var body: some Scene {
        WindowGroup("Routina", id: RoutinaMacSceneID.home) {
            homeRoot
                .environment(\.routinaMacFocusTimerStatusStore, focusTimerStatusStore)
                .background(RoutinaMacWindowRouterInstaller())
                .onAppear {
                    MacMenuCleanup.removeUnneededMenus()
                    DispatchQueue.main.async {
                        MacMenuCleanup.removeUnneededMenus()
                    }
                    widgetRefreshScheduler.schedule(delayNanoseconds: 300_000_000)
                    focusTimerStatusStore.refresh()
                    activateHomeWindow()
                }
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                    widgetRefreshScheduler.schedule()
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
                .environment(\.routinaMacFocusTimerStatusStore, focusTimerStatusStore)
        }
    }

    @MainActor
    private func activateHomeWindow() {
        RoutinaMacWindowRouter.shared.activateHomeWindow()
    }
}

@MainActor
private final class RoutinaMacWidgetRefreshScheduler {
    private let persistence: PersistenceController
    private var refreshTask: Task<Void, Never>?

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func schedule(delayNanoseconds: UInt64 = 150_000_000) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            self?.refreshNow()
        }
    }

    private func refreshNow() {
        WidgetStatsService.refresh(using: persistence.container)
        FocusTimerWidgetService.refresh(using: persistence.container)
        WidgetCenter.shared.reloadAllTimelines()
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
