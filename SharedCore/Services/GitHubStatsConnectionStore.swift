import Foundation

enum GitHubStatsConnectionStore {
    private enum Store {
        static let repositoryFilename = "GitHubRepository.json"
        static let accessTokenService = "Routina.GitHub"
        static let accessTokenAccount = "personal-access-token"
    }

    static func loadConnectionStatus() -> GitHubConnectionStatus {
        makeConnectionStatus(
            configuration: loadConfiguration(),
            hasAccessToken: storedAccessToken() != nil
        )
    }

    static func saveConnection(
        configuration: GitHubStatsConfiguration,
        accessToken: String?
    ) async throws -> GitHubConnectionStatus {
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
    }

    static func clearConnection() throws {
        try clearStoredConfiguration()
        try clearAccessToken()
    }

    static func loadConfiguration() -> GitHubStatsConfiguration? {
        guard let data = GitStatsFileStore.loadData(filename: Store.repositoryFilename) else { return nil }

        let decoder = JSONDecoder()
        if let configuration = try? decoder.decode(GitHubStatsConfiguration.self, from: data) {
            return configuration
        }

        if let repository = try? decoder.decode(GitHubRepositoryReference.self, from: data) {
            return GitHubStatsConfiguration(scope: .repository, repository: repository, viewerLogin: nil)
        }

        return nil
    }

    static func storedAccessToken() -> String? {
        GitStatsCredentialStore.storedAccessToken(
            service: Store.accessTokenService,
            account: Store.accessTokenAccount
        )
    }

    static func makeConnectionStatus(
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

    private static func saveStoredConfiguration(_ configuration: GitHubStatsConfiguration) throws {
        try GitStatsFileStore.save(configuration, filename: Store.repositoryFilename)
    }

    private static func clearStoredConfiguration() throws {
        try GitStatsFileStore.clear(filename: Store.repositoryFilename)
    }

    private static func storeAccessToken(_ accessToken: String) throws {
        do {
            try GitStatsCredentialStore.storeAccessToken(
                accessToken,
                service: Store.accessTokenService,
                account: Store.accessTokenAccount,
                failureMessage: "The GitHub token could not be stored securely."
            )
        } catch {
            throw GitHubStatsError.networkFailure("The GitHub token could not be stored securely.")
        }
    }

    private static func clearAccessToken() throws {
        do {
            try GitStatsCredentialStore.clearAccessToken(
                service: Store.accessTokenService,
                account: Store.accessTokenAccount,
                failureMessage: "The saved GitHub token could not be removed."
            )
        } catch {
            throw GitHubStatsError.networkFailure("The saved GitHub token could not be removed.")
        }
    }

    private static func validatedConfiguration(
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
}
