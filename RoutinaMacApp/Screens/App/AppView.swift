import SwiftUI
import ComposableArchitecture

struct AppView: View {
    let store: StoreOf<AppFeature>
    @State private var searchText = ""
    @AppStorage(UserDefaultStringValueKey.appSettingAppColorScheme.rawValue, store: SharedDefaults.app)
    private var appColorSchemeRawValue = AppColorScheme.system.rawValue

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

                SwiftUI.Tab(Tab.plan.rawValue, systemImage: "calendar", value: Tab.plan) {
                    DayPlanView()
                }

                SwiftUI.Tab(Tab.search.rawValue, systemImage: "magnifyingglass", value: Tab.search, role: .search) {
                    platformSearchHomeView(searchText: $searchText)
                }

                SwiftUI.Tab(Tab.goals.rawValue, systemImage: "target", value: Tab.goals) {
                    GoalsTCAView(
                        store: store.scope(state: \.goals, action: \.goals)
                    )
                }

                SwiftUI.Tab(Tab.timeline.rawValue, systemImage: "clock.arrow.circlepath", value: Tab.timeline) {
                    TimelineView(
                        store: store.scope(state: \.timeline, action: \.timeline)
                    )
                }

                SwiftUI.Tab(Tab.stats.rawValue, systemImage: "chart.bar.xaxis", value: Tab.stats) {
                    StatsViewWrapper(
                        store: store.scope(state: \.stats, action: \.stats)
                    )
                }

                SwiftUI.Tab(Tab.settings.rawValue, systemImage: "gear", value: Tab.settings) {
                    SettingsTCAView(
                        store: store.scope(state: \.settings, action: \.settings)
                    )
                }
            }
            Group {
                if store.selectedTab == .search {
                    tabView
                        .searchable(text: $searchText, prompt: "Search routines and todos")
                        .onReceive(NotificationCenter.default.publisher(for: CloudSettingsKeyValueSync.didChangeNotification)) { _ in
                            PlatformSupport.applyAppIcon(.persistedSelection)
                            store.send(.cloudSettingsChanged)
                        }
                        .task {
                            store.send(.onAppear)
                        }
                } else {
                    tabView
                        .onReceive(NotificationCenter.default.publisher(for: CloudSettingsKeyValueSync.didChangeNotification)) { _ in
                            PlatformSupport.applyAppIcon(.persistedSelection)
                            store.send(.cloudSettingsChanged)
                        }
                        .task {
                            store.send(.onAppear)
                        }
                }
            }
            .preferredColorScheme(appColorScheme.preferredColorScheme)
        }
    }

    private var appColorScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorSchemeRawValue) ?? .system
    }
}

private extension AppColorScheme {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
