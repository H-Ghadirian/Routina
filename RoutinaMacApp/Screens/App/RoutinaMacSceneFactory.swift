import AppKit
import SwiftUI

enum RoutinaMacSceneFactory {
    @MainActor
    static func makeHomeRoot(persistence: PersistenceController) -> AnyView {
        let store = RoutinaAppBootstrap.makeStore(
            using: persistence,
            platformClients: .macOSLive
        )

        return AnyView(
            RoutinaMacAppThemeRoot {
                AppLockGate {
                    HomeMacView(
                        appStore: store,
                        store: store.scope(state: \.home, action: \.home),
                        settingsStore: store.scope(state: \.settings, action: \.settings),
                        statsStore: store.scope(state: \.stats, action: \.stats)
                    )
                    .frame(
                        minWidth: RoutinaMacWindowSizing.minWidth,
                        minHeight: RoutinaMacWindowSizing.minHeight
                    )
                    .modelContainer(persistence.container)
                    .onAppear {
                        NSApplication.shared.registerForRemoteNotifications()
                        PlatformSupport.applyAppIcon(.persistedSelection)
                        Task {
                            await CloudKitPushSubscriptionService.ensureSubscriptionIfNeeded(
                                containerIdentifier: AppEnvironment.cloudKitContainerIdentifier
                            )
                        }
                    }
                }
            }
        )
    }

    @MainActor
    static func makeSettingsRoot(persistence: PersistenceController) -> AnyView {
        let store = RoutinaAppBootstrap.makeStore(
            using: persistence,
            platformClients: .macOSLive
        )

        return AnyView(
            RoutinaMacAppThemeRoot {
                AppLockGate {
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
        )
    }
}

private struct RoutinaMacAppThemeRoot<Content: View>: View {
    @AppStorage(UserDefaultStringValueKey.appSettingAppColorScheme.rawValue, store: SharedDefaults.app)
    private var appColorSchemeRawValue = AppColorScheme.system.rawValue

    @ViewBuilder var content: Content

    var body: some View {
        content
            .preferredColorScheme(appColorScheme.preferredColorScheme)
    }

    private var appColorScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorSchemeRawValue) ?? .system
    }
}

private extension AppColorScheme {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum RoutinaMacWindowSizing {
    static let defaultWidth: CGFloat = 1080
    static let defaultHeight: CGFloat = 680
    static let minWidth: CGFloat = 900
    static let minHeight: CGFloat = 560
}

enum RoutinaMacSettingsSizing {
    static let minWidth: CGFloat = 640
    static let minHeight: CGFloat = 560
}
