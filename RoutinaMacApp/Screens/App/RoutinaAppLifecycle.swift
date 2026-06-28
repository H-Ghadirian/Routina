import SwiftUI

private enum RoutinaAppWindowSizing {
    static let defaultWidth: CGFloat = 1280
    static let defaultHeight: CGFloat = 760
    static let minWidth: CGFloat = 1200
    static let minHeight: CGFloat = 720
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
