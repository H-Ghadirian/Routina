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
        let application = UIApplication.shared
        guard application.supportsAlternateIcons else {
            NSLog("Alternate app icons are not supported on this device.")
            return
        }

        let alternateIconName = option.iOSAlternateIconName
        guard application.alternateIconName != alternateIconName else {
            return
        }

        application.setAlternateIconName(alternateIconName) { error in
            if let error {
                NSLog("Failed to update app icon: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    static func requestAppIconChange(to option: AppIconOption) async -> String? {
        let application = UIApplication.shared
        guard application.supportsAlternateIcons else {
            return "This device does not support alternate app icons."
        }

        let alternateIconName = option.iOSAlternateIconName
        guard application.alternateIconName != alternateIconName else {
            return nil
        }

        var attemptsRemaining = 3
        while true {
            let error = await setAlternateIconName(alternateIconName, for: application)
            guard let error else {
                return nil
            }

            if isTransientAlternateIconError(error), attemptsRemaining > 0 {
                attemptsRemaining -= 1
                try? await Task.sleep(nanoseconds: 350_000_000)
                continue
            }

            return appIconErrorMessage(for: error)
        }
    }

    @MainActor
    private static func setAlternateIconName(
        _ alternateIconName: String?,
        for application: UIApplication
    ) async -> NSError? {
        await withCheckedContinuation { continuation in
            application.setAlternateIconName(alternateIconName) { error in
                continuation.resume(returning: error as NSError?)
            }
        }
    }

    private static func isTransientAlternateIconError(_ error: NSError) -> Bool {
        guard error.domain == NSPOSIXErrorDomain else {
            return false
        }
        return error.code == EAGAIN || error.localizedDescription == "Resource temporarily unavailable"
    }

    private static func appIconErrorMessage(for error: NSError) -> String {
#if targetEnvironment(simulator)
        if isTransientAlternateIconError(error) {
            return "iOS Simulator is currently rejecting alternate icon changes. Test this on a physical iPhone or an iOS 26.0 simulator runtime."
        }
#endif
        return error.localizedDescription
    }
}

extension View {
    func routinaInlineTitleDisplayMode() -> some View {
        navigationBarTitleDisplayMode(.inline)
    }

    func routinaGraphSheetFrame() -> some View {
        self
    }
}
