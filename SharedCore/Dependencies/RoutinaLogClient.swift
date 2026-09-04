import Dependencies
import Foundation
import OSLog

struct RoutinaLogClient: Sendable {
    var error: @Sendable (String) -> Void
    var notice: @Sendable (String) -> Void

    static let live = Self(
        error: { message in
            Logger.routinaOperations.error("\(message, privacy: .private(mask: .hash))")
        },
        notice: { message in
            Logger.routinaOperations.notice("\(message, privacy: .private(mask: .hash))")
        }
    )

    static let noop = Self(
        error: { _ in },
        notice: { _ in }
    )
}

enum RoutinaLog {
    static func error(_ message: @autoclosure () -> String) {
        @Dependency(\.routinaLogClient) var client
        client.error(message())
    }

    static func notice(_ message: @autoclosure () -> String) {
        @Dependency(\.routinaLogClient) var client
        client.notice(message())
    }
}

private extension Logger {
    static let routinaOperations = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Routina",
        category: "Operations"
    )
}
