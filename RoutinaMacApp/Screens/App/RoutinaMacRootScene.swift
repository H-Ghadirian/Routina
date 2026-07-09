import AppKit
import SwiftUI
import SwiftData

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
        guard MacAppWidgetAvailability.isEnabled else { return }

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
        FocusTimerWidgetService.refreshAndReload(using: persistence.container)
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
    private weak var observedWindow: NSWindow?
    private var windowNotificationTokens: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeWindowIfNeeded(window)
        RoutinaMacHomeWindowChrome.configure(window)
    }

    private func observeWindowIfNeeded(_ window: NSWindow?) {
        guard observedWindow !== window else { return }

        removeWindowObservers()
        observedWindow = window

        guard let window else { return }

        let center = NotificationCenter.default
        windowNotificationTokens = [
            center.addObserver(
                forName: NSWindow.didEnterFullScreenNotification,
                object: window,
                queue: .main
            ) { [weak window] _ in
                RoutinaMacHomeWindowChrome.configureFullscreenTitlebarMode(
                    isFullscreen: true,
                    for: window
                )
            },
            center.addObserver(
                forName: NSWindow.didExitFullScreenNotification,
                object: window,
                queue: .main
            ) { [weak window] _ in
                RoutinaMacHomeWindowChrome.configureFullscreenTitlebarMode(
                    isFullscreen: false,
                    for: window
                )
            },
        ]
    }

    private func removeWindowObservers() {
        for token in windowNotificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        windowNotificationTokens.removeAll()
        observedWindow = nil
    }
}

private enum RoutinaMacHomeWindowChrome {
    static func configure(_ window: NSWindow?) {
        MainActor.assumeIsolated {
            guard let window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            setFullSizeContentView(
                isEnabled: !window.styleMask.contains(.fullScreen),
                for: window
            )
            window.toolbarStyle = .unifiedCompact
            window.titlebarSeparatorStyle = .none
            window.toolbar?.sizeMode = .small
            window.minSize = NSSize(
                width: RoutinaMacWindowSizing.minWidth,
                height: RoutinaMacWindowSizing.minHeight
            )
        }
    }

    static func configureFullscreenTitlebarMode(isFullscreen: Bool, for window: NSWindow?) {
        MainActor.assumeIsolated {
            guard let window else { return }
            setFullSizeContentView(isEnabled: !isFullscreen, for: window)
        }
    }

    @MainActor
    private static func setFullSizeContentView(isEnabled: Bool, for window: NSWindow) {
        if isEnabled {
            window.styleMask.insert(.fullSizeContentView)
        } else {
            window.styleMask.remove(.fullSizeContentView)
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
