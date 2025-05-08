import SwiftUI

extension AppView {
    var platformHomeView: some View {
        HomeTCAView(
            store: store.scope(state: \.home, action: \.home)
        )
    }

    func platformSearchHomeView(searchText: Binding<String>) -> some View {
        HomeTCAView(
            store: store.scope(state: \.home, action: \.home),
            searchText: searchText
        )
    }
}
