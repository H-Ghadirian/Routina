import Foundation

struct GitHubStatsClient: Sendable {
    var loadConnectionStatus: @Sendable () -> GitHubConnectionStatus
    var saveConnection: @Sendable (GitHubStatsConfiguration, String?) async throws -> GitHubConnectionStatus
    var clearConnection: @Sendable () throws -> Void
    var fetchStats: @Sendable (DoneChartRange) async throws -> GitHubStatsSnapshot
    var fetchContributionYear: @Sendable () async throws -> GitHubWidgetData
}

extension GitHubStatsClient {
    static let live = GitHubStatsClient(
        loadConnectionStatus: {
            GitHubStatsConnectionStore.loadConnectionStatus()
        },
        saveConnection: { configuration, accessToken in
            try await GitHubStatsConnectionStore.saveConnection(
                configuration: configuration,
                accessToken: accessToken
            )
        },
        clearConnection: {
            try GitHubStatsConnectionStore.clearConnection()
        },
        fetchStats: { range in
            guard let configuration = GitHubStatsConnectionStore.loadConfiguration() else {
                throw GitHubStatsError.notConfigured
            }

            let accessToken = GitHubStatsConnectionStore.storedAccessToken()
            let referenceDate = Date()
            switch configuration.scope {
            case .repository:
                guard let repository = configuration.repository, repository.isConfigured else {
                    throw GitHubStatsError.invalidRepository
                }

                return .repository(
                    try await fetchRepositoryStats(
                        for: repository,
                        range: range,
                        referenceDate: referenceDate,
                        accessToken: accessToken
                    )
                )

            case .profile:
                guard let accessToken, !accessToken.isEmpty else {
                    throw GitHubStatsError.profileTokenRequired
                }

                return .profile(
                    try await fetchProfileStats(
                        range: range,
                        referenceDate: referenceDate,
                        accessToken: accessToken,
                        fallbackLogin: configuration.viewerLogin
                    )
                )
            }
        },
        fetchContributionYear: {
            guard let configuration = GitHubStatsConnectionStore.loadConfiguration() else {
                throw GitHubStatsError.notConfigured
            }
            guard configuration.scope == .profile else {
                throw GitHubStatsError.notConfigured
            }
            guard let accessToken = GitHubStatsConnectionStore.storedAccessToken(), !accessToken.isEmpty else {
                throw GitHubStatsError.profileTokenRequired
            }
            return try await fetchWidgetContributions(
                accessToken: accessToken,
                fallbackLogin: configuration.viewerLogin
            )
        }
    )

    static let noop = GitHubStatsClient(
        loadConnectionStatus: { .disconnected },
        saveConnection: { configuration, _ in
            GitHubStatsConnectionStore.makeConnectionStatus(
                configuration: configuration,
                hasAccessToken: false
            )
        },
        clearConnection: { },
        fetchStats: { _ in
            throw GitHubStatsError.notConfigured
        },
        fetchContributionYear: {
            throw GitHubStatsError.notConfigured
        }
    )
}
