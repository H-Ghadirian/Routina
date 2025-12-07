import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct RoutinaTCAApp: App {
    #if os(macOS)
    private enum WindowSizing {
        static let defaultWidth: CGFloat = 1080
        static let defaultHeight: CGFloat = 680
        static let minWidth: CGFloat = 900
        static let minHeight: CGFloat = 560
    }
    #endif

    init() {
        let cloudContainer = AppEnvironment.cloudKitContainerIdentifier ?? "disabled"
        NSLog(
            "Routina data mode: \(AppEnvironment.dataModeLabel), defaults suite: \(AppEnvironment.userDefaultsSuiteName), cloud container: \(cloudContainer)"
        )
        SharedDefaults.app.register(defaults: [
            .appSettingNotificationsEnabled: true
        ])
    }

    var body: some Scene {
        WindowGroup {
            let persistence = PersistenceController.shared
            let store = Store(
                initialState: AppFeature.State(),
                reducer: { AppFeature() },
                withDependencies: {
                    $0.modelContext = { @MainActor in persistence.container.mainContext }
                }
            )

            AppView(store: store)
                #if os(macOS)
                .frame(minWidth: WindowSizing.minWidth, minHeight: WindowSizing.minHeight)
                #endif
                .modelContainer(persistence.container)
        }
        #if os(macOS)
        .defaultSize(width: WindowSizing.defaultWidth, height: WindowSizing.defaultHeight)
        .windowResizability(.contentMinSize)
        #endif
    }
}
