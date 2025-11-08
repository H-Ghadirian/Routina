import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PlatformSupport {
    static var didBecomeActiveNotification: Notification.Name {
        #if canImport(UIKit)
        UIApplication.didBecomeActiveNotification
        #elseif canImport(AppKit)
        NSApplication.didBecomeActiveNotification
        #else
        Notification.Name("AppDidBecomeActive")
        #endif
    }

    static var notificationSettingsURL: URL? {
        #if canImport(UIKit)
        URL(string: UIApplication.openSettingsURLString)
        #elseif canImport(AppKit)
        URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        #else
        nil
        #endif
    }

    @MainActor
    static func open(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }
}

extension View {
    @ViewBuilder
    func routinaInlineTitleDisplayMode() -> some View {
        #if os(macOS)
        self
        #else
        self.navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

