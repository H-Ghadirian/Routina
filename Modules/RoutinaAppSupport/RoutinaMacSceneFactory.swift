#if os(macOS)
import AppKit
import SwiftUI

package enum RoutinaMacSceneFactory {
    @MainActor
    package static func makeHomeRoot(persistence: PersistenceController) -> AnyView {
        let store = RoutinaAppBootstrap.makeStore(using: persistence)

        return AnyView(
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
                Task {
                    await CloudKitPushSubscriptionService.ensureSubscriptionIfNeeded(
                        containerIdentifier: AppEnvironment.cloudKitContainerIdentifier
                    )
                }
            }
        )
    }

    @MainActor
    package static func makeStatsRoot(persistence: PersistenceController) -> AnyView {
        AnyView(
            StatsView()
                .frame(
                    minWidth: RoutinaMacStatsSizing.minWidth,
                    minHeight: RoutinaMacStatsSizing.minHeight
                )
                .modelContainer(persistence.container)
        )
    }

    @MainActor
    package static func makeSettingsRoot(persistence: PersistenceController) -> AnyView {
        let store = RoutinaAppBootstrap.makeStore(using: persistence)

        return AnyView(
            SettingsTCAView(
                store: store.scope(state: \.settings, action: \.settings)
            )
            .frame(
                minWidth: RoutinaMacSettingsSizing.minWidth,
                minHeight: RoutinaMacSettingsSizing.minHeight
            )
            .modelContainer(persistence.container)
        )
    }
}

package enum RoutinaMacWindowSizing {
    package static let defaultWidth: CGFloat = 1080
    package static let defaultHeight: CGFloat = 680
    package static let minWidth: CGFloat = 900
    package static let minHeight: CGFloat = 560
}

package enum RoutinaMacSettingsSizing {
    package static let minWidth: CGFloat = 640
    package static let minHeight: CGFloat = 560
}

package enum RoutinaMacStatsSizing {
    package static let defaultWidth: CGFloat = 900
    package static let defaultHeight: CGFloat = 620
    package static let minWidth: CGFloat = 760
    package static let minHeight: CGFloat = 520
}
#endif
