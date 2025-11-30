#if os(macOS)
import SwiftUI

private enum RoutinaAppWindowSizing {
    static let defaultWidth: CGFloat = 1080
    static let defaultHeight: CGFloat = 680
    static let minWidth: CGFloat = 900
    static let minHeight: CGFloat = 560
}

extension View {
    func routinaAppRootWindowFrame() -> some View {
        frame(
            minWidth: RoutinaAppWindowSizing.minWidth,
            minHeight: RoutinaAppWindowSizing.minHeight
        )
    }
}

extension Scene {
    func routinaAppWindowDefaults() -> some Scene {
        defaultSize(
            width: RoutinaAppWindowSizing.defaultWidth,
            height: RoutinaAppWindowSizing.defaultHeight
        )
        .windowResizability(.contentMinSize)
    }
}
#endif
