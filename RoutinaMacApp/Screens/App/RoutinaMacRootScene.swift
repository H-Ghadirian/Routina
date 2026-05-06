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
        self.persistence = persistence
        self.homeRoot = RoutinaMacSceneFactory.makeHomeRoot(persistence: persistence)
        self.settingsRoot = RoutinaMacSceneFactory.makeSettingsRoot(persistence: persistence)
        self.focusTimerStatusStore = RoutinaMacFocusTimerStatusStore(persistence: persistence)
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
        .commands {
            RoutineCommands()
        }

        MenuBarExtra {
            RoutinaMacMenuBarContent(focusTimerStatusStore: focusTimerStatusStore)
        } label: {
            RoutinaMacMenuBarIcon(focusTimerStatusStore: focusTimerStatusStore)
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}

private enum RoutinaMacSceneID {
    static let home = "routina-home"
}

private struct RoutinaMacMenuBarContent: View {
    @ObservedObject var focusTimerStatusStore: RoutinaMacFocusTimerStatusStore

    var body: some View {
        Group {
            if focusTimerStatusStore.status.isActive {
                RoutinaMacMenuBarFocusSummary(status: focusTimerStatusStore.status)
                Divider()
            }

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
        .task {
            focusTimerStatusStore.refresh()
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
    @ObservedObject var focusTimerStatusStore: RoutinaMacFocusTimerStatusStore

    var body: some View {
        Group {
            if focusTimerStatusStore.status.isActive {
                RoutinaMacActiveFocusMenuBarLabel(status: focusTimerStatusStore.status)
            } else {
                Image(systemName: "checklist.checked")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .task {
            focusTimerStatusStore.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            focusTimerStatusStore.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            focusTimerStatusStore.refresh()
        }
    }
}

private struct RoutinaMacActiveFocusMenuBarLabel: View {
    let status: RoutinaMacFocusTimerStatus

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 5) {
                Image(systemName: status.kind?.systemImage ?? "timer")
                    .font(.system(size: 13, weight: .semibold))
                Text(status.menuBarTimeText(at: context.date))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .help("\(status.kind?.displayTitle ?? "Focus Timer"): \(status.shortTitle)")
        }
    }
}

private struct RoutinaMacMenuBarFocusSummary: View {
    let status: RoutinaMacFocusTimerStatus

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 4) {
                Label(status.kind?.displayTitle ?? "Focus Timer", systemImage: status.kind?.systemImage ?? "timer")
                    .font(.headline)

                Text(status.shortTitle)
                    .font(.subheadline)

                Text("\(status.menuBarTimeText(at: context.date)) \(status.menuBarModeText(at: context.date))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}
