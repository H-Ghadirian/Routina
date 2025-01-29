import SwiftUI
import ComposableArchitecture

@main
struct RoutinaTCAApp: App {
    var body: some Scene {
        WindowGroup {
            AppView(
                store: StoreOf<AppFeature>(initialState: .init(), reducer: {})
            )
        }
    }
}
