import Foundation
import Security

struct GitHubStatsClient: Sendable {
    var loadConnectionStatus: @Sendable () -> GitHubConnectionStatus
    var saveConnection: @Sendable (GitHubStatsConfiguration, String?) async throws -> GitHubConnectionStatus
    var clearConnection: @Sendable () throws -> Void
    var fetchStats: @Sendable (DoneChartRange) async throws -> GitHubStatsSnapshot
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

                return .repository(
                    GitHubRepositoryStats(
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

private struct GitHubGraphQLRequest: Encodable {
    let query: String
    let variables: [String: String]
}

private struct GitHubGraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GitHubGraphQLError]?
}

private struct GitHubGraphQLError: Decodable {
    let message: String
}

private struct GitHubViewerLoginPayload: Decodable {
    struct ViewerPayload: Decodable {
        let login: String
    }

    let viewer: ViewerPayload
}

private struct GitHubViewerContributionsPayload: Decodable {
    struct ViewerPayload: Decodable {
        struct ContributionsCollectionPayload: Decodable {
            struct CalendarPayload: Decodable {
                struct WeekPayload: Decodable {
                    struct DayPayload: Decodable {
                        let contributionCount: Int
                        let date: String
                    }

                    let contributionDays: [DayPayload]
                }

                let totalContributions: Int
                let weeks: [WeekPayload]
            }

            let contributionCalendar: CalendarPayload
            let totalCommitContributions: Int
            let totalIssueContributions: Int
            let totalPullRequestContributions: Int
            let totalPullRequestReviewContributions: Int
            let totalRepositoriesWithContributedCommits: Int
            let restrictedContributionsCount: Int
        }

        let login: String
        let contributionsCollection: ContributionsCollectionPayload
    }

    let viewer: ViewerPayload
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
    guard
        let url = try? gitHubRepositoryStoreURL(),
        FileManager.default.fileExists(atPath: url.path),
        let data = try? Data(contentsOf: url)
    else {
        return nil
    }

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
    let url = try gitHubRepositoryStoreURL()
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let data = try JSONEncoder().encode(configuration)
    try data.write(to: url, options: [.atomic])
}

private func clearStoredConfiguration() throws {
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

private func fetchProfileStats(
    range: DoneChartRange,
    referenceDate: Date,
    accessToken: String,
    fallbackLogin: String?
) async throws -> GitHubProfileStats {
    let window = makeGitHubStatsWindow(range: range, referenceDate: referenceDate)
    let variables = [
        "from": makeGitHubDateTimeString(window.startDate),
        "to": makeGitHubDateTimeString(window.endDate)
    ]

    let query = """
    query ViewerContributions($from: DateTime!, $to: DateTime!) {
      viewer {
        login
        contributionsCollection(from: $from, to: $to) {
          contributionCalendar {
            totalContributions
            weeks {
              contributionDays {
                contributionCount
                date
              }
            }
          }
          totalCommitContributions
          totalIssueContributions
          totalPullRequestContributions
          totalPullRequestReviewContributions
          totalRepositoriesWithContributedCommits
          restrictedContributionsCount
        }
      }
    }
    """

    let payload: GitHubViewerContributionsPayload = try await decodeGitHubGraphQLResponse(
        query: query,
        variables: variables,
        accessToken: accessToken
    )

    let contributionDays = payload.viewer.contributionsCollection.contributionCalendar.weeks
        .flatMap(\.contributionDays)
    let contributionPoints = makeContributionPoints(
        from: contributionDays,
        range: range,
        referenceDate: referenceDate
    )

    return GitHubProfileStats(
        login: payload.viewer.login.isEmpty ? (fallbackLogin ?? "viewer") : payload.viewer.login,
        range: range,
        fetchedAt: referenceDate,
        contributionPoints: contributionPoints,
        totalContributionCount: payload.viewer.contributionsCollection.contributionCalendar.totalContributions,
        totalCommitCount: payload.viewer.contributionsCollection.totalCommitContributions,
        totalPullRequestCount: payload.viewer.contributionsCollection.totalPullRequestContributions,
        totalPullRequestReviewCount: payload.viewer.contributionsCollection.totalPullRequestReviewContributions,
        totalIssueCount: payload.viewer.contributionsCollection.totalIssueContributions,
        contributedRepositoryCount: payload.viewer.contributionsCollection.totalRepositoriesWithContributedCommits,
        restrictedContributionCount: payload.viewer.contributionsCollection.restrictedContributionsCount,
        averageContributionCount: RoutineCompletionStats.averageCount(in: contributionPoints),
        busiestContributionDay: RoutineCompletionStats.busiestDay(in: contributionPoints)
    )
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

private func fetchViewerLogin(accessToken: String) async throws -> String {
    let payload: GitHubViewerLoginPayload = try await decodeGitHubGraphQLResponse(
        query: """
        query ViewerLogin {
          viewer {
            login
          }
        }
        """,
        variables: [:],
        accessToken: accessToken
    )
    return payload.viewer.login
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

private func decodeGitHubGraphQLResponse<T: Decodable>(
    query: String,
    variables: [String: String],
    accessToken: String
) async throws -> T {
    guard let url = URL(string: "https://api.github.com/graphql") else {
        throw GitHubStatsError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.setValue("Routina", forHTTPHeaderField: "User-Agent")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(
        GitHubGraphQLRequest(query: query, variables: variables)
    )

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubStatsError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let payload = try makeGitHubDecoder().decode(GitHubGraphQLResponse<T>.self, from: data)
            if let errors = payload.errors, let firstError = errors.first {
                throw mapGitHubGraphQLError(firstError.message)
            }
            guard let value = payload.data else {
                throw GitHubStatsError.invalidResponse
            }
            return value
        case 401 where httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0":
            throw GitHubStatsError.rateLimited
        case 403 where httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0":
            throw GitHubStatsError.rateLimited
        case 401:
            throw GitHubStatsError.unauthorized
        case 403:
            throw GitHubStatsError.rateLimited
        default:
            throw GitHubStatsError.invalidResponse
        }
    } catch let error as GitHubStatsError {
        throw error
    } catch {
        throw GitHubStatsError.networkFailure(error.localizedDescription)
    }
}

private func mapGitHubGraphQLError(_ message: String) -> GitHubStatsError {
    let lowered = message.lowercased()
    if lowered.contains("rate limit") {
        return .rateLimited
    }
    if lowered.contains("bad credentials")
        || lowered.contains("requires authentication")
        || lowered.contains("resource not accessible")
    {
        return .unauthorized
    }
    return .networkFailure(message)
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

private func makeGitHubStatsWindow(
    range: DoneChartRange,
    referenceDate: Date
) -> (startDate: Date, endDate: Date) {
    let calendar = Calendar.current
    let endDate = referenceDate
    let startDate = calendar.date(
        byAdding: .day,
        value: -(range.trailingDayCount - 1),
        to: calendar.startOfDay(for: referenceDate)
    ) ?? referenceDate
    return (startDate, endDate)
}

private func makeGitHubDateTimeString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}

private func makeContributionPoints(
    from days: [GitHubViewerContributionsPayload.ViewerPayload.ContributionsCollectionPayload.CalendarPayload.WeekPayload.DayPayload],
    range: DoneChartRange,
    referenceDate: Date
) -> [DoneChartPoint] {
    let calendar = Calendar.current
    let window = makeGitHubStatsWindow(range: range, referenceDate: referenceDate)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"

    let countsByDay = Dictionary(
        uniqueKeysWithValues: days.compactMap { day -> (Date, Int)? in
            guard let date = formatter.date(from: day.date) else { return nil }
            let normalized = calendar.startOfDay(for: date)
            guard normalized >= calendar.startOfDay(for: window.startDate),
                  normalized <= calendar.startOfDay(for: window.endDate)
            else {
                return nil
            }
            return (normalized, day.contributionCount)
        }
    )

    return (0..<range.trailingDayCount).compactMap { offset in
        guard let date = calendar.date(
            byAdding: .day,
            value: offset,
            to: calendar.startOfDay(for: window.startDate)
        ) else {
            return nil
        }

        return DoneChartPoint(date: date, count: countsByDay[date] ?? 0)
    }
}
