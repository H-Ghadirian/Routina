import AppKit
import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct RoutinaMacApp: App {
    @NSApplicationDelegateAdaptor(RemoteNotificationMacDelegate.self) private var remoteNotificationDelegate

    private let persistence: PersistenceController
    private let store: StoreOf<AppFeature>

    @MainActor
    init() {
        RoutinaAppBootstrap.configure()

        let persistence = PersistenceController.shared
        self.persistence = persistence
        self.store = RoutinaAppBootstrap.makeStore(using: persistence)
    }

    var body: some Scene {
        WindowGroup {
            HomeTCAView(
                store: store.scope(state: \.home, action: \.home)
            )
            .frame(
                minWidth: RoutinaMacWindowSizing.minWidth,
                minHeight: RoutinaMacWindowSizing.minHeight
            )
            .modelContainer(persistence.container)
            .onAppear {
                NSApplication.shared.registerForRemoteNotifications()
                PlatformSupport.applyAppIcon(.persistedSelection)
                MacMenuCleanup.removeUnneededMenus()
                DispatchQueue.main.async {
                    MacMenuCleanup.removeUnneededMenus()
                }
                Task {
                    await CloudKitPushSubscriptionService.ensureSubscriptionIfNeeded(
                        containerIdentifier: AppEnvironment.cloudKitContainerIdentifier
                    )
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
            StatsView()
                .frame(
                    minWidth: RoutinaMacStatsSizing.minWidth,
                    minHeight: RoutinaMacStatsSizing.minHeight
                )
                .modelContainer(persistence.container)
        }
        .defaultSize(
            width: RoutinaMacStatsSizing.defaultWidth,
            height: RoutinaMacStatsSizing.defaultHeight
        )
        .windowResizability(.contentMinSize)

        Settings {
            SettingsTCAView(
                store: store.scope(state: \.settings, action: \.settings)
            )
            .frame(
                minWidth: RoutinaMacSettingsSizing.minWidth,
                minHeight: RoutinaMacSettingsSizing.minHeight
            )
            .modelContainer(persistence.container)
        }
    }
}

private enum RoutinaMacWindowSizing {
    static let defaultWidth: CGFloat = 1080
    static let defaultHeight: CGFloat = 680
    static let minWidth: CGFloat = 900
    static let minHeight: CGFloat = 560
}

private enum RoutinaMacSettingsSizing {
    static let minWidth: CGFloat = 640
    static let minHeight: CGFloat = 560
}

private enum RoutinaMacStatsSizing {
    static let defaultWidth: CGFloat = 900
    static let defaultHeight: CGFloat = 620
    static let minWidth: CGFloat = 760
    static let minHeight: CGFloat = 520
}
