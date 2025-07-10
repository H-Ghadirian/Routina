import Foundation

enum GitHubStatsScope: String, Codable, CaseIterable, Equatable, Sendable, Identifiable {
    case repository
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .repository:
            return "Repository"
        case .profile:
            return "Profile"
        }
    }

    var subtitle: String {
        switch self {
        case .repository:
            return "Track one repo's commits and pull requests"
        case .profile:
            return "Track your full GitHub contribution activity"
        }
    }
}

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

struct GitHubStatsConfiguration: Codable, Equatable, Sendable {
    var scope: GitHubStatsScope = .repository
    var repository: GitHubRepositoryReference?
    var viewerLogin: String?
}

struct GitHubConnectionStatus: Equatable, Sendable {
    var scope: GitHubStatsScope = .repository
    var repository: GitHubRepositoryReference?
    var viewerLogin: String?
    var hasAccessToken: Bool = false

    var isConnected: Bool {
        switch scope {
        case .repository:
            return repository?.isConfigured == true
        case .profile:
            return hasAccessToken && viewerLogin?.isEmpty == false
        }
    }

    static let disconnected = GitHubConnectionStatus()

    static func disconnected(scope: GitHubStatsScope) -> GitHubConnectionStatus {
        GitHubConnectionStatus(scope: scope)
    }
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

struct GitHubProfileStats: Equatable, Sendable {
    var login: String
    var range: DoneChartRange
    var fetchedAt: Date
    var contributionPoints: [DoneChartPoint]
    var totalContributionCount: Int
    var totalCommitCount: Int
    var totalPullRequestCount: Int
    var totalPullRequestReviewCount: Int
    var totalIssueCount: Int
    var contributedRepositoryCount: Int
    var restrictedContributionCount: Int
    var averageContributionCount: Double
    var busiestContributionDay: DoneChartPoint?
}

enum GitHubStatsSnapshot: Equatable, Sendable {
    case repository(GitHubRepositoryStats)
    case profile(GitHubProfileStats)
}

enum GitHubStatsError: Error, Equatable, LocalizedError, Sendable {
    case notConfigured
    case invalidRepository
    case profileTokenRequired
    case unauthorized
    case repositoryNotFound
    case rateLimited
    case invalidResponse
    case networkFailure(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Connect GitHub in Settings to load activity stats."
        case .invalidRepository:
            return "Enter a valid repository owner and name."
        case .profileTokenRequired:
            return "Add a GitHub personal access token in Settings to load profile activity."
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
