import Foundation

struct GitLabWidgetData: Codable, Sendable {
    struct Week: Codable, Sendable {
        struct Day: Codable, Sendable {
            let date: String
            let count: Int
        }
        let days: [Day]
    }

    let username: String
    let weeks: [Week]
    let totalContributions: Int
    let fetchedAt: Date
}

struct GitLabConnectionStatus: Equatable, Sendable {
    var username: String?
    var hasAccessToken: Bool = false

    var isConnected: Bool {
        hasAccessToken && (username?.isEmpty == false)
    }

    static let disconnected = GitLabConnectionStatus()
}

enum GitLabStatsError: Error, Equatable, LocalizedError, Sendable {
    case notConfigured
    case tokenRequired
    case unauthorized
    case rateLimited
    case invalidResponse
    case networkFailure(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Connect GitLab in Settings to show your contribution graph."
        case .tokenRequired:
            return "Add a GitLab personal access token in Settings."
        case .unauthorized:
            return "GitLab rejected the request. Check the token scopes (needs read_api)."
        case .rateLimited:
            return "GitLab rate limited the request. Try again in a moment."
        case .invalidResponse:
            return "GitLab returned an unexpected response."
        case let .networkFailure(message):
            return message
        }
    }
}
