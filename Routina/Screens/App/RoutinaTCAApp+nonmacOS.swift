#if !os(macOS)
import SwiftUI

extension View {
    func routinaAppRootWindowFrame() -> some View {
        self
    }
}

extension Scene {
    func routinaAppWindowDefaults() -> some Scene {
        self
    }
}
#endif
