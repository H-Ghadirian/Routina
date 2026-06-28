import AppKit
import SwiftUI
import SwiftData
import WidgetKit

struct RoutinaMacRootScene: Scene {
    private let persistence: PersistenceController
    private let homeRoot: AnyView
    private let settingsRoot: AnyView
    private let focusTimerStatusStore: RoutinaMacFocusTimerStatusStore
    private let widgetRefreshScheduler: RoutinaMacWidgetRefreshScheduler

    @MainActor
    init() {
        let persistence = RoutinaAppSceneBootstrap.preparePersistence()
        let focusTimerStatusStore = RoutinaMacFocusTimerStatusStore(persistence: persistence)
        let homeRoot = RoutinaMacSceneFactory.makeHomeRoot(persistence: persistence)
        self.persistence = persistence
        self.homeRoot = homeRoot
        self.settingsRoot = RoutinaMacSceneFactory.makeSettingsRoot(persistence: persistence)
        self.focusTimerStatusStore = focusTimerStatusStore
        self.widgetRefreshScheduler = RoutinaMacWidgetRefreshScheduler(persistence: persistence)
        RoutinaMacFocusTimerStatusBarController.shared.configure(store: focusTimerStatusStore)
        if !AppEnvironment.isAutomatedTestMode {
            MacBatteryRoutineMonitor.shared.startIfNeeded {
                persistence.container.mainContext
            }
        }
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
                .background(RoutinaMacHomeWindowConfigurator())
                .background(RoutinaMacUndoBridge(persistence: persistence))
                .onAppear {
                    MacMenuCleanup.removeUnneededMenus()
                    DispatchQueue.main.async {
                        MacMenuCleanup.removeUnneededMenus()
                    }
                    widgetRefreshScheduler.scheduleLaunchRefresh()
                    focusTimerStatusStore.refresh()
                    activateHomeWindow()
                }
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                    focusTimerStatusStore.scheduleRefresh()
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
                .background(RoutinaMacUndoBridge(persistence: persistence))
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
    private var focusRefreshTask: Task<Void, Never>?
    private var statsRefreshTask: Task<Void, Never>?

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func scheduleLaunchRefresh() {
        scheduleFocusRefresh(delayNanoseconds: 300_000_000)
        scheduleStatsRefresh(delayNanoseconds: 2_000_000_000)
    }

    private func scheduleFocusRefresh(delayNanoseconds: UInt64) {
        focusRefreshTask?.cancel()
        focusRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            self?.refreshFocusTimerWidget()
        }
    }

    private func scheduleStatsRefresh(delayNanoseconds: UInt64) {
        statsRefreshTask?.cancel()
        statsRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            self?.refreshStatsWidget()
        }
    }

    private func refreshFocusTimerWidget() {
        FocusTimerWidgetService.refresh(using: persistence.container)
        WidgetCenter.shared.reloadTimelines(ofKind: FocusTimerWidgetService.widgetKind)
    }

    private func refreshStatsWidget() {
        WidgetStatsService.refreshAndReload(using: persistence.container)
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

private struct RoutinaMacHomeWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> RoutinaMacHomeWindowConfigurationView {
        RoutinaMacHomeWindowConfigurationView()
    }

    func updateNSView(_ view: RoutinaMacHomeWindowConfigurationView, context: Context) {
        RoutinaMacHomeWindowChrome.configure(view.window)
    }
}

private final class RoutinaMacHomeWindowConfigurationView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        RoutinaMacHomeWindowChrome.configure(window)
    }
}

private enum RoutinaMacHomeWindowChrome {
    static func configure(_ window: NSWindow?) {
        MainActor.assumeIsolated {
            guard let window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbarStyle = .unified
            window.minSize = NSSize(
                width: RoutinaMacWindowSizing.minWidth,
                height: RoutinaMacWindowSizing.minHeight
            )
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
        RoutinaMacHomeWindowChrome.configure(window)
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
