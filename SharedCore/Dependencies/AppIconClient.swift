import Foundation

struct AppIconClient: Sendable {
    var requestChange: @Sendable (AppIconOption) async -> String?
}

extension AppIconClient {
    static let noop = AppIconClient(
        requestChange: { _ in nil }
    )
}
