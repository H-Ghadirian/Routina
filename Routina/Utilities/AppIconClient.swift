import Foundation

struct AppIconClient: Sendable {
    var requestChange: @Sendable (AppIconOption) async -> String?
}

extension AppIconClient {
    static let live = AppIconClient(
        requestChange: { option in
            await PlatformSupport.requestAppIconChange(to: option)
        }
    )
}
