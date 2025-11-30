#if canImport(UIKit)
import Foundation
import SwiftUI
import UIKit

extension PlatformSupport {
    static var didBecomeActiveNotification: Notification.Name {
        UIApplication.didBecomeActiveNotification
    }

    static var notificationSettingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

    @MainActor
    static func open(_ url: URL) {
        UIApplication.shared.open(url)
    }
}

extension View {
    func routinaInlineTitleDisplayMode() -> some View {
        navigationBarTitleDisplayMode(.inline)
    }
}
#endif
