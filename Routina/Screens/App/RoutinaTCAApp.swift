import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct RoutinaTCAApp: App {
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
                .routinaAppRootWindowFrame()
                .modelContainer(persistence.container)
        }
        .routinaAppWindowDefaults()
    }
}
