import SwiftUI

extension AppView {
    var platformHomeView: some View {
        HomeTCAView(
            store: store.scope(state: \.home, action: \.home),
            settingsStore: store.scope(state: \.settings, action: \.settings),
            goalsStore: store.scope(state: \.goals, action: \.goals),
            statsStore: store.scope(state: \.stats, action: \.stats),
            backlogStore: store.scope(state: \.backlog, action: \.backlog),
            taskRankingStore: store.scope(state: \.taskRanking, action: \.taskRanking)
        )
    }

    func platformSearchHomeView(searchText: Binding<String>) -> some View {
        HomeTCAView(
            store: store.scope(state: \.home, action: \.home),
            settingsStore: store.scope(state: \.settings, action: \.settings),
            goalsStore: store.scope(state: \.goals, action: \.goals),
            statsStore: store.scope(state: \.stats, action: \.stats),
            backlogStore: store.scope(state: \.backlog, action: \.backlog),
            taskRankingStore: store.scope(state: \.taskRanking, action: \.taskRanking),
            searchText: searchText
        )
    }
}
