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

    @MainActor
    static func selectRoutineDataExportURL(suggestedFileName: String) -> URL? {
        _ = suggestedFileName
        return nil
    }

    @MainActor
    static func selectRoutineDataImportURL() -> URL? {
        nil
    }

    @MainActor
    static func applyAppIcon(_ option: AppIconOption) {
        _ = option
    }

    @MainActor
    static func requestAppIconChange(to option: AppIconOption) async -> String? {
        _ = option
        return "Alternate app icons are unavailable on this platform."
    }
}

extension View {
    func routinaInlineTitleDisplayMode() -> some View {
        self
    }
}
#endif
