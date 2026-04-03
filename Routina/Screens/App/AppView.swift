import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>
    @State private var searchText = ""

    var body: some View {
        WithPerceptionTracking {
            let tabView = TabView(
                selection: Binding(
                    get: { store.selectedTab },
                    set: { store.send(.tabSelected($0)) }
                )
            ) {
                SwiftUI.Tab(Tab.home.rawValue, systemImage: "house", value: Tab.home) {
                    platformHomeView
                }

                SwiftUI.Tab(Tab.search.rawValue, systemImage: "magnifyingglass", value: Tab.search, role: .search) {
                    platformSearchHomeView(searchText: $searchText)
                }

                SwiftUI.Tab(Tab.timeline.rawValue, systemImage: "clock.arrow.circlepath", value: Tab.timeline) {
                    TimelineView()
                }

                SwiftUI.Tab(Tab.stats.rawValue, systemImage: "chart.bar.xaxis", value: Tab.stats) {
                    StatsView()
                }

                SwiftUI.Tab(Tab.settings.rawValue, systemImage: "gear", value: Tab.settings) {
                    SettingsTCAView(
                        store: store.scope(state: \.settings, action: \.settings)
                    )
                }
            }
            if store.selectedTab == .search {
                tabView
                    .searchable(text: $searchText, prompt: "Search routines and todos")
                    .task {
                        store.send(.onAppear)
                    }
            } else {
                tabView
                    .task {
                        store.send(.onAppear)
                    }
            }
        }
    }
}
