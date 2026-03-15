#if !os(macOS)
import SwiftUI

extension View {
    func routinaHomeSidebarColumnWidth() -> some View {
        self
    }
}

extension HomeTCAView {
    func applyPlatformSidebarSearch<Content: View>(
        to view: Content,
        searchText: Binding<String>
    ) -> some View {
        view.searchable(text: searchText, prompt: "Search routines")
    }

    @ViewBuilder
    func platformSearchField(searchText: Binding<String>) -> some View {
        EmptyView()
    }

    func applyPlatformRefresh<Content: View>(to view: Content) -> some View {
        view.refreshable {
            await performManualRefresh()
        }
    }

    @ViewBuilder
    var platformRefreshButton: some View {
        EmptyView()
    }
}
#endif
