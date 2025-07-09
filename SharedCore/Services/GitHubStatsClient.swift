import Foundation
import Security

struct GitHubStatsClient: Sendable {
    var loadConnectionStatus: @Sendable () -> GitHubConnectionStatus
    var saveConnection: @Sendable (GitHubRepositoryReference, String?) async throws -> GitHubConnectionStatus
    var clearConnection: @Sendable () throws -> Void
    var fetchStats: @Sendable (DoneChartRange) async throws -> GitHubRepositoryStats
}

extension GitHubStatsClient {
    static let live = GitHubStatsClient(
        loadConnectionStatus: {
            let repository = loadStoredRepository()
            return GitHubConnectionStatus(
                repository: repository,
                hasAccessToken: storedAccessToken() != nil
            )
        },
        saveConnection: { repository, accessToken in
            guard repository.isConfigured else {
                throw GitHubStatsError.invalidRepository
            }

            if let accessToken, !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try storeAccessToken(accessToken)
            }

            let token = storedAccessToken()
            try await validateRepository(repository, accessToken: token)
            try saveStoredRepository(repository)

            return GitHubConnectionStatus(
                repository: repository,
                hasAccessToken: token != nil
            )
        },
        clearConnection: {
            try clearStoredRepository()
            try clearAccessToken()
        },
        fetchStats: { range in
            guard let repository = loadStoredRepository(), repository.isConfigured else {
                throw GitHubStatsError.notConfigured
            }

            let accessToken = storedAccessToken()
            let referenceDate = Date()
            let commitDates = try await fetchCommitDates(
                for: repository,
                range: range,
                referenceDate: referenceDate,
                accessToken: accessToken
            )
            let commitPoints = RoutineCompletionStats.points(
                for: range,
                timestamps: commitDates.map(\.date),
                referenceDate: referenceDate
            )

            return GitHubRepositoryStats(
                repository: repository,
                range: range,
                fetchedAt: referenceDate,
                commitPoints: commitPoints,
                totalCommitCount: commitDates.count,
                mergedPullRequestCount: try await fetchMergedPullRequestCount(
                    for: repository,
                    range: range,
                    referenceDate: referenceDate,
                    accessToken: accessToken
                ),
                openPullRequestCount: try await fetchOpenPullRequestCount(
                    for: repository,
                    accessToken: accessToken
                ),
                contributorCount: Set(commitDates.map(\.authorKey)).count,
                averageCommitCount: RoutineCompletionStats.averageCount(in: commitPoints),
                busiestCommitDay: RoutineCompletionStats.busiestDay(in: commitPoints)
            )
        }
    )

    static let noop = GitHubStatsClient(
        loadConnectionStatus: { .disconnected },
        saveConnection: { repository, _ in
            GitHubConnectionStatus(repository: repository, hasAccessToken: false)
        },
        clearConnection: { },
        fetchStats: { _ in
            throw GitHubStatsError.notConfigured
        }
    )
}

private struct GitHubCommitPageEntry: Decodable {
    struct CommitPayload: Decodable {
        struct AuthorPayload: Decodable {
            let date: Date
        }

        let author: AuthorPayload?
    }

    struct UserPayload: Decodable {
        let login: String?
    }

    let commit: CommitPayload
    let author: UserPayload?
}

private struct GitHubCommitAggregate: Sendable {
    let date: Date
    let authorKey: String
}

private struct GitHubSearchResult: Decodable {
    let totalCount: Int

    private enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
    }
}

private struct GitHubRepositoryPayload: Decodable {
    let fullName: String

    private enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}

private enum GitHubStore {
    static let repositoryFilename = "GitHubRepository.json"
    static let accessTokenService = "Routina.GitHub"
    static let accessTokenAccount = "personal-access-token"
}

private func loadStoredRepository() -> GitHubRepositoryReference? {
    guard
        let url = try? gitHubRepositoryStoreURL(),
        FileManager.default.fileExists(atPath: url.path),
        let data = try? Data(contentsOf: url)
    else {
        return nil
    }

    return try? JSONDecoder().decode(GitHubRepositoryReference.self, from: data)
}

private func saveStoredRepository(_ repository: GitHubRepositoryReference) throws {
    let url = try gitHubRepositoryStoreURL()
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let data = try JSONEncoder().encode(repository)
    try data.write(to: url, options: [.atomic])
}

private func clearStoredRepository() throws {
    let url = try gitHubRepositoryStoreURL()
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    try FileManager.default.removeItem(at: url)
}

private func gitHubRepositoryStoreURL() throws -> URL {
    let applicationSupportDirectory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let storesDirectory = applicationSupportDirectory.appendingPathComponent("RoutinaData", isDirectory: true)
    return storesDirectory.appendingPathComponent(GitHubStore.repositoryFilename)
}

private func storedAccessToken() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: GitHubStore.accessTokenService,
        kSecAttrAccount as String: GitHubStore.accessTokenAccount,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status != errSecItemNotFound else { return nil }
    guard status == errSecSuccess,
          let data = item as? Data,
          let token = String(data: data, encoding: .utf8),
          !token.isEmpty
    else {
        return nil
    }

    return token
}

private func storeAccessToken(_ accessToken: String) throws {
    let data = Data(accessToken.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
    let baseQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: GitHubStore.accessTokenService,
        kSecAttrAccount as String: GitHubStore.accessTokenAccount
    ]

    let attributes: [String: Any] = [
        kSecValueData as String: data
    ]

    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess {
        return
    }

    var addQuery = baseQuery
    addQuery[kSecValueData as String] = data
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
        throw GitHubStatsError.networkFailure("The GitHub token could not be stored securely.")
    }
}

private func clearAccessToken() throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: GitHubStore.accessTokenService,
        kSecAttrAccount as String: GitHubStore.accessTokenAccount
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
        throw GitHubStatsError.networkFailure("The saved GitHub token could not be removed.")
    }
}

private func validateRepository(
    _ repository: GitHubRepositoryReference,
    accessToken: String?
) async throws {
    let components = makeGitHubComponents(path: "/repos/\(repository.owner)/\(repository.name)")
    let _: GitHubRepositoryPayload = try await decodeGitHubResponse(
        components: components,
        accessToken: accessToken
    )
}

private func fetchCommitDates(
    for repository: GitHubRepositoryReference,
    range: DoneChartRange,
    referenceDate: Date,
    accessToken: String?
) async throws -> [GitHubCommitAggregate] {
    let calendar = Calendar.current
    let endDate = referenceDate
    guard let startDate = calendar.date(
        byAdding: .day,
        value: -(range.trailingDayCount - 1),
        to: calendar.startOfDay(for: referenceDate)
    ) else {
        return []
    }

    var page = 1
    var results: [GitHubCommitAggregate] = []
    var hasNextPage = true

    while hasNextPage {
        var components = makeGitHubComponents(path: "/repos/\(repository.owner)/\(repository.name)/commits")
        let formatter = ISO8601DateFormatter()
        components.queryItems = [
            URLQueryItem(name: "since", value: formatter.string(from: startDate)),
            URLQueryItem(name: "until", value: formatter.string(from: endDate)),
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "page", value: "\(page)")
        ]

        let (entries, response) = try await decodeGitHubResponseWithMetadata(
            components: components,
            accessToken: accessToken,
            as: [GitHubCommitPageEntry].self
        )

        results.append(
            contentsOf: entries.compactMap { entry in
                guard let date = entry.commit.author?.date else { return nil }
                let authorKey = entry.author?.login ?? "unknown"
                return GitHubCommitAggregate(date: date, authorKey: authorKey)
            }
        )

        hasNextPage = response.hasNextPage
        page += 1
    }

    return results
}

private func fetchMergedPullRequestCount(
    for repository: GitHubRepositoryReference,
    range: DoneChartRange,
    referenceDate: Date,
    accessToken: String?
) async throws -> Int {
    let calendar = Calendar.current
    guard let startDate = calendar.date(
        byAdding: .day,
        value: -(range.trailingDayCount - 1),
        to: calendar.startOfDay(for: referenceDate)
    ) else {
        return 0
    }

    let formatter = ISO8601DateFormatter()
    let startDateString = formatter.string(from: startDate)
    let endDateString = formatter.string(from: referenceDate)
    let mergedQuery = "repo:\(repository.fullName) is:pr is:merged merged:\(startDateString)..\(endDateString)"

    return try await searchCount(
        query: mergedQuery,
        accessToken: accessToken
    )
}

private func fetchOpenPullRequestCount(
    for repository: GitHubRepositoryReference,
    accessToken: String?
) async throws -> Int {
    try await searchCount(
        query: "repo:\(repository.fullName) is:pr is:open",
        accessToken: accessToken
    )
}

private func searchCount(
    query: String,
    accessToken: String?
) async throws -> Int {
    var components = makeGitHubComponents(path: "/search/issues")
    components.queryItems = [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "per_page", value: "1")
    ]
    let result: GitHubSearchResult = try await decodeGitHubResponse(
        components: components,
        accessToken: accessToken
    )
    return result.totalCount
}

private struct GitHubResponseMetadata: Sendable {
    let hasNextPage: Bool
}

private func decodeGitHubResponse<T: Decodable>(
    components: URLComponents,
    accessToken: String?,
    decoder: JSONDecoder = makeGitHubDecoder()
) async throws -> T {
    let (value, _) = try await decodeGitHubResponseWithMetadata(
        components: components,
        accessToken: accessToken,
        as: T.self,
        decoder: decoder
    )
    return value
}

private func decodeGitHubResponseWithMetadata<T: Decodable>(
    components: URLComponents,
    accessToken: String?,
    as type: T.Type,
    decoder: JSONDecoder = makeGitHubDecoder()
) async throws -> (T, GitHubResponseMetadata) {
    guard let url = components.url else {
        throw GitHubStatsError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.setValue("Routina", forHTTPHeaderField: "User-Agent")
    if let accessToken, !accessToken.isEmpty {
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubStatsError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let value = try decoder.decode(type, from: data)
            let linkHeader = httpResponse.value(forHTTPHeaderField: "Link") ?? ""
            return (
                value,
                GitHubResponseMetadata(hasNextPage: linkHeader.contains("rel=\"next\""))
            )
        case 401 where httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0":
            throw GitHubStatsError.rateLimited
        case 403 where httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0":
            throw GitHubStatsError.rateLimited
        case 401:
            throw GitHubStatsError.unauthorized
        case 403:
            throw GitHubStatsError.rateLimited
        case 404:
            throw GitHubStatsError.repositoryNotFound
        default:
            throw GitHubStatsError.invalidResponse
        }
    } catch let error as GitHubStatsError {
        throw error
    } catch {
        throw GitHubStatsError.networkFailure(error.localizedDescription)
    }
}

private func makeGitHubDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}

private func makeGitHubComponents(path: String) -> URLComponents {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.github.com"
    components.path = path
    return components
}
