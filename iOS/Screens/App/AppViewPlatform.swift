import SwiftUI

extension AppView {
    var platformHomeView: some View {
        HomeIOSView(
            store: store.scope(state: \.home, action: \.home),
            timelineStore: store.scope(state: \.timeline, action: \.timeline),
            backlogStore: store.scope(state: \.backlog, action: \.backlog),
            taskRankingStore: store.scope(state: \.taskRanking, action: \.taskRanking),
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
