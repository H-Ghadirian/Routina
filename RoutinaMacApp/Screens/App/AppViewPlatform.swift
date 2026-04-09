import SwiftUI

extension AppView {
    var platformHomeView: some View {
        HomeTCAView(
            store: store.scope(state: \.home, action: \.home),
            settingsStore: store.scope(state: \.settings, action: \.settings),
            statsStore: store.scope(state: \.stats, action: \.stats)
        )
    }

    func platformSearchHomeView(searchText: Binding<String>) -> some View {
        HomeTCAView(
            store: store.scope(state: \.home, action: \.home),
            settingsStore: store.scope(state: \.settings, action: \.settings),
            statsStore: store.scope(state: \.stats, action: \.stats),
            searchText: searchText
        )
    }
}
