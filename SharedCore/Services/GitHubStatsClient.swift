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
            makeConnectionStatus(
                configuration: loadStoredConfiguration(),
                hasAccessToken: storedAccessToken() != nil
            )
        },
        saveConnection: { configuration, accessToken in
            if let accessToken, !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try storeAccessToken(accessToken)
            }

            let token = storedAccessToken()
            let normalizedConfiguration = try await validatedConfiguration(
                configuration,
                accessToken: token
            )
            try saveStoredConfiguration(normalizedConfiguration)

            return makeConnectionStatus(
                configuration: normalizedConfiguration,
                hasAccessToken: token != nil
            )
        },
        clearConnection: {
            try clearStoredConfiguration()
            try clearAccessToken()
        },
        fetchStats: { range in
            guard let configuration = loadStoredConfiguration() else {
                throw GitHubStatsError.notConfigured
            }

            let accessToken = storedAccessToken()
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
            guard let configuration = loadStoredConfiguration() else {
                throw GitHubStatsError.notConfigured
            }
            guard configuration.scope == .profile else {
                throw GitHubStatsError.notConfigured
            }
            guard let accessToken = storedAccessToken(), !accessToken.isEmpty else {
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
            makeConnectionStatus(configuration: configuration, hasAccessToken: false)
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

private enum GitHubStore {
    static let repositoryFilename = "GitHubRepository.json"
    static let accessTokenService = "Routina.GitHub"
    static let accessTokenAccount = "personal-access-token"
}

private func makeConnectionStatus(
    configuration: GitHubStatsConfiguration?,
    hasAccessToken: Bool
) -> GitHubConnectionStatus {
    GitHubConnectionStatus(
        scope: configuration?.scope ?? .repository,
        repository: configuration?.repository,
        viewerLogin: configuration?.viewerLogin,
        hasAccessToken: hasAccessToken
    )
}

private func loadStoredConfiguration() -> GitHubStatsConfiguration? {
    guard let data = GitStatsFileStore.loadData(filename: GitHubStore.repositoryFilename) else { return nil }

    let decoder = JSONDecoder()
    if let configuration = try? decoder.decode(GitHubStatsConfiguration.self, from: data) {
        return configuration
    }

    if let repository = try? decoder.decode(GitHubRepositoryReference.self, from: data) {
        return GitHubStatsConfiguration(scope: .repository, repository: repository, viewerLogin: nil)
    }

    return nil
}

private func saveStoredConfiguration(_ configuration: GitHubStatsConfiguration) throws {
    try GitStatsFileStore.save(configuration, filename: GitHubStore.repositoryFilename)
}

private func clearStoredConfiguration() throws {
    try GitStatsFileStore.clear(filename: GitHubStore.repositoryFilename)
}

private func storedAccessToken() -> String? {
    GitStatsCredentialStore.storedAccessToken(
        service: GitHubStore.accessTokenService,
        account: GitHubStore.accessTokenAccount
    )
}

private func storeAccessToken(_ accessToken: String) throws {
    do {
        try GitStatsCredentialStore.storeAccessToken(
            accessToken,
            service: GitHubStore.accessTokenService,
            account: GitHubStore.accessTokenAccount,
            failureMessage: "The GitHub token could not be stored securely."
        )
    } catch {
        throw GitHubStatsError.networkFailure("The GitHub token could not be stored securely.")
    }
}

private func clearAccessToken() throws {
    do {
        try GitStatsCredentialStore.clearAccessToken(
            service: GitHubStore.accessTokenService,
            account: GitHubStore.accessTokenAccount,
            failureMessage: "The saved GitHub token could not be removed."
        )
    } catch {
        throw GitHubStatsError.networkFailure("The saved GitHub token could not be removed.")
    }
}

private func validatedConfiguration(
    _ configuration: GitHubStatsConfiguration,
    accessToken: String?
) async throws -> GitHubStatsConfiguration {
    switch configuration.scope {
    case .repository:
        guard let repository = configuration.repository, repository.isConfigured else {
            throw GitHubStatsError.invalidRepository
        }
        try await validateRepository(repository, accessToken: accessToken)
        return GitHubStatsConfiguration(scope: .repository, repository: repository, viewerLogin: nil)

    case .profile:
        guard let accessToken, !accessToken.isEmpty else {
            throw GitHubStatsError.profileTokenRequired
        }
        let viewerLogin = try await fetchViewerLogin(accessToken: accessToken)
        return GitHubStatsConfiguration(scope: .profile, repository: nil, viewerLogin: viewerLogin)
    }
}
