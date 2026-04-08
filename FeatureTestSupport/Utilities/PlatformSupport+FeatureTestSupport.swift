import Foundation
import SwiftUI

enum PlatformSupport {}

extension PlatformSupport {
    static var didBecomeActiveNotification: Notification.Name {
        Notification.Name("AppDidBecomeActive")
    }

    static var notificationSettingsURL: URL? {
        nil
    }

    @MainActor
    static func open(_ url: URL) {
        _ = url
    }

    @MainActor
    static func selectRoutineDataExportURL(suggestedFileName: String) async -> URL? {
        _ = suggestedFileName
        return nil
    }

    @MainActor
    static func selectRoutineDataImportURL() async -> URL? {
        nil
    }

    @MainActor
    static func applyAppIcon(_ option: AppIconOption) {
        _ = option
    }

    @MainActor
    static func requestAppIconChange(to option: AppIconOption) async -> String? {
        _ = option
        return "Alternate app icons are unavailable in package support."
    }
}

extension View {
    func routinaInlineTitleDisplayMode() -> some View {
        self
    }
}
