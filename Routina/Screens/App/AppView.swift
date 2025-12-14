import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        WithPerceptionTracking {
            TabView(
                selection: Binding(
                    get: { store.selectedTab },
                    set: { store.send(.tabSelected($0)) }
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
            .task {
                store.send(.onAppear)
            }
        }
    }
}
