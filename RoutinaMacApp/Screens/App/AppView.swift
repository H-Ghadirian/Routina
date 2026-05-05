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
                            handlePendingDeepLink()
                        }
                        .onOpenURL(perform: handleOpenURL)
                        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
                            handleDeepLinkNotification(notification)
                        }
                } else {
                    tabView
                        .onReceive(NotificationCenter.default.publisher(for: CloudSettingsKeyValueSync.didChangeNotification)) { _ in
                            PlatformSupport.applyAppIcon(.persistedSelection)
                            store.send(.cloudSettingsChanged)
                        }
                        .task {
                            store.send(.onAppear)
                            handlePendingDeepLink()
                        }
                        .onOpenURL(perform: handleOpenURL)
                        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
                            handleDeepLinkNotification(notification)
                        }
                }
            }
            .preferredColorScheme(appColorScheme.preferredColorScheme)
        }
    }

    private var appColorScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorSchemeRawValue) ?? .system
    }

    private func handleOpenURL(_ url: URL) {
        guard let deepLink = RoutinaDeepLink(url: url) else { return }
        store.send(.openDeepLink(deepLink))
    }

    @MainActor
    private func handleDeepLinkNotification(_ notification: Notification) {
        guard let deepLink = RoutinaDeepLinkDispatcher.deepLink(from: notification) else { return }
        RoutinaDeepLinkDispatcher.markHandled(deepLink)
        store.send(.openDeepLink(deepLink))
    }

    @MainActor
    private func handlePendingDeepLink() {
        guard let deepLink = RoutinaDeepLinkDispatcher.consumePendingDeepLink() else { return }
        store.send(.openDeepLink(deepLink))
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
