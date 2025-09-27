#if !os(macOS)
import SwiftUI

extension View {
    func routinaHomeSidebarColumnWidth() -> some View {
        self
    }
}

extension HomeTCAView {
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
