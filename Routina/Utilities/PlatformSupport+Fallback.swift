#if !canImport(UIKit) && !canImport(AppKit)
import Foundation
import SwiftUI

extension PlatformSupport {
    static var didBecomeActiveNotification: Notification.Name {
        Notification.Name("AppDidBecomeActive")
    }

    static var notificationSettingsURL: URL? {
        nil
    }

    @MainActor
    static func open(_ url: URL) { }
}

extension View {
    func routinaInlineTitleDisplayMode() -> some View {
        self
    }
}
#endif
