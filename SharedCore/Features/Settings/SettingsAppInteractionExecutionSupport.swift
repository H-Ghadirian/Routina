import Foundation

enum SettingsAppInteractionExecution {
    @MainActor
    static func openNotificationSettings(
        urlOpenerClient: URLOpenerClient
    ) {
        guard let url = urlOpenerClient.notificationSettingsURL() else {
            return
        }

        urlOpenerClient.open(url)
    }

    @MainActor
    static func contactSupport(
        urlOpenerClient: URLOpenerClient
    ) {
        guard let emailURL = URL(string: "mailto:h.qadirian@gmail.com") else {
            return
        }

        urlOpenerClient.open(emailURL)
    }

    static func requestAppIconChange(
        _ option: AppIconOption,
        appIconClient: AppIconClient
    ) async -> String? {
        await appIconClient.requestChange(option)
    }
}
