import SwiftUI

extension AppView {
    var platformHomeView: some View {
        HomeIOSView(
            store: store.scope(state: \.home, action: \.home),
            isActive: store.selectedTab == .home
        )
    }

    func platformSearchHomeView(searchText: Binding<String>) -> some View {
        HomeIOSView(
            store: store.scope(state: \.home, action: \.home),
            searchText: searchText,
            isActive: store.selectedTab == .search
        )
    }
}
