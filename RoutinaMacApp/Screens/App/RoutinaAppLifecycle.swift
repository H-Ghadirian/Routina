import SwiftUI

private enum RoutinaAppWindowSizing {
    static let defaultWidth: CGFloat = 1440
    static let defaultHeight: CGFloat = 760
    static let minWidth: CGFloat = 1440
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
    }
}
