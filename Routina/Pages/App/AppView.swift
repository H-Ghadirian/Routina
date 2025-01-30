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
                HomeTCAView(
                    store: store.scope(state: \.home, action: \.home)
                )
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: "house")
                }
                .tag(Tab.home)

                SettingsTCAView(
                    store: store.scope(state: \.settings, action: \.settings)
                )
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: "gear")
                }
                .tag(Tab.settings)
            }
        }
    }
}
