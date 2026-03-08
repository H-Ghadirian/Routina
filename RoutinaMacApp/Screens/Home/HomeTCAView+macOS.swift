#if os(macOS)
import SwiftUI

private enum HomeSidebarSizing {
    static let minWidth: CGFloat = 320
    static let idealWidth: CGFloat = 380
    static let maxWidth: CGFloat = 520
}

extension View {
    func routinaHomeSidebarColumnWidth() -> some View {
        navigationSplitViewColumnWidth(
            min: HomeSidebarSizing.minWidth,
            ideal: HomeSidebarSizing.idealWidth,
            max: HomeSidebarSizing.maxWidth
        )
    }
}

extension HomeTCAView {
    func applyPlatformRefresh<Content: View>(to view: Content) -> some View {
        view
    }

    @ViewBuilder
    var platformRefreshButton: some View {
        Button {
            Task { @MainActor in
                await performManualRefresh()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }
}
#endif
