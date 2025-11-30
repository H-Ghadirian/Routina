#if canImport(AppKit)
import AppKit
import Foundation
import SwiftUI

extension PlatformSupport {
    static var didBecomeActiveNotification: Notification.Name {
        NSApplication.didBecomeActiveNotification
    }

    static var notificationSettingsURL: URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
    }

    @MainActor
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

extension View {
    func routinaInlineTitleDisplayMode() -> some View {
        self
    }
}
#endif
