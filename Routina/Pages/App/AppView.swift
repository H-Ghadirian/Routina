import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        WithViewStore(store, observe: \.selectedTab) { viewStore in
            TabView(
                selection: viewStore.binding(
                    get: { $0 },
                    send: { .tabSelected($0) }
                )
            ) {
            }
        }
    }
}
