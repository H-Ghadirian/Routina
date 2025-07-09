import Foundation

struct GitHubRepositoryReference: Codable, Equatable, Sendable {
    var owner: String
    var name: String

    init(owner: String, name: String) {
        self.owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var fullName: String {
        "\(owner)/\(name)"
    }

    var isConfigured: Bool {
        !owner.isEmpty && !name.isEmpty
    }
}

struct GitHubConnectionStatus: Equatable, Sendable {
    var repository: GitHubRepositoryReference?
    var hasAccessToken: Bool = false

    var isConnected: Bool {
        repository?.isConfigured == true
    }

    static let disconnected = GitHubConnectionStatus()
}

struct GitHubRepositoryStats: Equatable, Sendable {
    var repository: GitHubRepositoryReference
    var range: DoneChartRange
    var fetchedAt: Date
    var commitPoints: [DoneChartPoint]
    var totalCommitCount: Int
    var mergedPullRequestCount: Int
    var openPullRequestCount: Int
    var contributorCount: Int
    var averageCommitCount: Double
    var busiestCommitDay: DoneChartPoint?
}

enum GitHubStatsError: Error, Equatable, LocalizedError, Sendable {
    case notConfigured
    case invalidRepository
    case unauthorized
    case repositoryNotFound
    case rateLimited
    case invalidResponse
    case networkFailure(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Set a GitHub repository in Settings to load stats."
        case .invalidRepository:
            return "Enter a valid repository owner and name."
        case .unauthorized:
            return "GitHub rejected the request. Check the access token permissions."
        case .repositoryNotFound:
            return "GitHub could not find that repository."
        case .rateLimited:
            return "GitHub rate limited the request. Try again in a moment or add a token."
        case .invalidResponse:
            return "GitHub returned an unexpected response."
        case let .networkFailure(message):
            return message
        }
    }
}
