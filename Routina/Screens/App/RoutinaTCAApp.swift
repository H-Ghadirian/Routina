import SwiftUI
import ComposableArchitecture

@main
struct RoutinaTCAApp: App {

    init() {
        NSLog(
            "Routina data mode: \(AppEnvironment.dataModeLabel), store: \(AppEnvironment.persistentStoreFileName), defaults suite: \(AppEnvironment.userDefaultsSuiteName), cloud container: \(AppEnvironment.cloudKitContainerIdentifier ?? "disabled")"
        )
        SharedDefaults.app.register(defaults: [
            .appSettingNotificationsEnabled: true
        ])
    }

    var body: some Scene {
        WindowGroup {
            let store = Store(
              initialState: AppFeature.State(),
              reducer: { AppFeature() },
              withDependencies: {
                $0.managedObjectContext = PersistenceController.shared.container.viewContext
              }
            )

            AppView(store: store)
        }
    }
}
