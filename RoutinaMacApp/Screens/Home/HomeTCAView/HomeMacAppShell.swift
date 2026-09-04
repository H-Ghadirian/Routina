import AppKit
import Combine
import ComposableArchitecture
import Foundation
import SwiftUI

struct HomeMacView: View {
    let appStore: StoreOf<AppFeature>
    let store: StoreOf<HomeFeature>
    let settingsStore: StoreOf<SettingsFeature>
    let goalsStore: StoreOf<GoalsFeature>
    let statsStore: StoreOf<StatsFeature>
    let backlogStore: StoreOf<BacklogFeature>
    let taskRankingStore: StoreOf<TaskRankingFeature>

    var body: some View {
        HomeTCAView(
            store: store,
            settingsStore: settingsStore,
            goalsStore: goalsStore,
            statsStore: statsStore,
            backlogStore: backlogStore,
            taskRankingStore: taskRankingStore,
            openActiveFocusTarget: { deepLink in
                guard let deepLink else { return }
                appStore.send(.openDeepLink(deepLink))
            }
        )
        .awayModeGate()
        .sleepModeGate()
        .task {
            appStore.send(.onAppear)
            handlePendingDeepLink()
        }
        .onOpenURL(perform: handleOpenURL)
        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
            handleDeepLinkNotification(notification)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            settingsStore.send(.onAppBecameActive)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: CloudKitSyncDiagnostics.didUpdateNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            settingsStore.send(.cloudDiagnosticsUpdated)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: CloudSettingsKeyValueSync.didChangeNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            appStore.send(.cloudSettingsChanged)
            store.send(.onAppear)
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard let deepLink = RoutinaDeepLink(url: url) else { return }
        RoutinaDeepLinkDispatcher.open(deepLink)
    }

    @MainActor
    private func handleDeepLinkNotification(_ notification: Notification) {
        guard let deepLink = RoutinaDeepLinkDispatcher.deepLink(from: notification) else { return }
        RoutinaDeepLinkDispatcher.markHandled(deepLink)
        appStore.send(.openDeepLink(deepLink))
    }

    @MainActor
    private func handlePendingDeepLink() {
        guard let deepLink = RoutinaDeepLinkDispatcher.consumePendingDeepLink() else { return }
        appStore.send(.openDeepLink(deepLink))
    }
}

extension View {
    @ViewBuilder
    func routinaMacHomeToolbarTitlebarIntegration(isFullscreen: Bool) -> some View {
        if isFullscreen {
            self
        } else {
            ignoresSafeArea(edges: .top)
        }
    }
}

struct HomeMacWindowFullscreenObserver: NSViewRepresentable {
    @Binding var isFullscreen: Bool

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isFullscreen = $isFullscreen
        context.coordinator.attach(to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isFullscreen: $isFullscreen)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        var isFullscreen: Binding<Bool>
        private weak var observedWindow: NSWindow?
        private var notificationObservers: [NSObjectProtocol] = []
        private var isAttachRetryScheduled = false

        init(isFullscreen: Binding<Bool>) {
            self.isFullscreen = isFullscreen
        }

        func attach(to view: NSView) {
            guard let window = view.window else {
                guard !isAttachRetryScheduled else { return }
                isAttachRetryScheduled = true
                Task { @MainActor [weak self, weak view] in
                    self?.isAttachRetryScheduled = false
                    guard let view else { return }
                    self?.attach(to: view)
                }
                return
            }

            guard observedWindow !== window else {
                update(from: window)
                return
            }

            detach()
            observedWindow = window
            update(from: window)

            let center = NotificationCenter.default
            notificationObservers = [
                center.addObserver(
                    forName: NSWindow.willEnterFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.setFullscreen(true)
                    }
                },
                center.addObserver(
                    forName: NSWindow.didEnterFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    Task { @MainActor [weak self, weak window] in
                        guard let window else { return }
                        self?.update(from: window)
                    }
                },
                center.addObserver(
                    forName: NSWindow.willExitFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.setFullscreen(false)
                    }
                },
                center.addObserver(
                    forName: NSWindow.didExitFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    Task { @MainActor [weak self, weak window] in
                        guard let window else { return }
                        self?.update(from: window)
                    }
                },
            ]
        }

        func detach() {
            notificationObservers.forEach(NotificationCenter.default.removeObserver)
            notificationObservers.removeAll()
            observedWindow = nil
        }

        private func update(from window: NSWindow) {
            setFullscreen(window.styleMask.contains(.fullScreen))
        }

        private func setFullscreen(_ value: Bool) {
            guard isFullscreen.wrappedValue != value else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isFullscreen.wrappedValue != value else { return }
                self.isFullscreen.wrappedValue = value
            }
        }
    }
}
