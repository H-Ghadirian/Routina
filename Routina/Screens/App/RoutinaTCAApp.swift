import SwiftUI
import ComposableArchitecture

@main
struct RoutinaTCAApp: App {
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
