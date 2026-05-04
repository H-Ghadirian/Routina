import Foundation

struct GitLabStatsClient: Sendable {
    var loadConnectionStatus: @Sendable () -> GitLabConnectionStatus
    var saveConnection: @Sendable (String) async throws -> GitLabConnectionStatus
    var clearConnection: @Sendable () throws -> Void
    var fetchContributionYear: @Sendable () async throws -> GitLabWidgetData
}

extension GitLabStatsClient {
    static let live = GitLabStatsClient(
        loadConnectionStatus: {
            GitLabConnectionStatus(
                username: loadStoredUsername(),
                hasAccessToken: storedAccessToken() != nil
            )
        },
        saveConnection: { accessToken in
            let trimmed = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw GitLabStatsError.tokenRequired }
            try storeAccessToken(trimmed)
            let username = try await fetchAuthenticatedUsername(accessToken: trimmed)
            try saveStoredUsername(username)
            return GitLabConnectionStatus(username: username, hasAccessToken: true)
        },
        clearConnection: {
            try clearStoredUsername()
            try clearAccessToken()
        },
        fetchContributionYear: {
            guard let accessToken = storedAccessToken(), !accessToken.isEmpty else {
                throw GitLabStatsError.tokenRequired
            }
            let username: String
            if let stored = loadStoredUsername() {
                username = stored
            } else {
                username = try await fetchAuthenticatedUsername(accessToken: accessToken)
            }
            return try await fetchWidgetContributions(accessToken: accessToken, username: username)
        }
    )

    static let noop = GitLabStatsClient(
        loadConnectionStatus: { .disconnected },
        saveConnection: { _ in .disconnected },
        clearConnection: { },
        fetchContributionYear: { throw GitLabStatsError.notConfigured }
    )
}

private enum GitLabStore {
    static let usernameFilename = "GitLabUser.json"
    static let accessTokenService = "Routina.GitLab"
    static let accessTokenAccount = "personal-access-token"
    static let host = "gitlab.com"
}

private struct StoredGitLabUser: Codable {
    let username: String
}

private func loadStoredUsername() -> String? {
    GitStatsFileStore.load(
        StoredGitLabUser.self,
        filename: GitLabStore.usernameFilename
    )?.username
}

private func saveStoredUsername(_ username: String) throws {
    try GitStatsFileStore.save(
        StoredGitLabUser(username: username),
        filename: GitLabStore.usernameFilename
    )
}

private func clearStoredUsername() throws {
    try GitStatsFileStore.clear(filename: GitLabStore.usernameFilename)
}

private func storedAccessToken() -> String? {
    GitStatsCredentialStore.storedAccessToken(
        service: GitLabStore.accessTokenService,
        account: GitLabStore.accessTokenAccount
    )
}

private func storeAccessToken(_ accessToken: String) throws {
    do {
        try GitStatsCredentialStore.storeAccessToken(
            accessToken,
            service: GitLabStore.accessTokenService,
            account: GitLabStore.accessTokenAccount,
            failureMessage: "The GitLab token could not be stored securely."
        )
    } catch {
        throw GitLabStatsError.networkFailure("The GitLab token could not be stored securely.")
    }
}

private func clearAccessToken() throws {
    do {
        try GitStatsCredentialStore.clearAccessToken(
            service: GitLabStore.accessTokenService,
            account: GitLabStore.accessTokenAccount,
            failureMessage: "The saved GitLab token could not be removed."
        )
    } catch {
        throw GitLabStatsError.networkFailure("The saved GitLab token could not be removed.")
    }
}

private func fetchAuthenticatedUser(accessToken: String) async throws -> GitLabUserPayload {
    var components = makeGitLabComponents(path: "/api/v4/user")
    components.queryItems = nil
    return try await decodeGitLabResponse(
        components: components,
        accessToken: accessToken
    )
}

private func fetchAuthenticatedUsername(accessToken: String) async throws -> String {
    try await fetchAuthenticatedUser(accessToken: accessToken).username
}

private func fetchWidgetContributions(
    accessToken: String,
    username: String
) async throws -> GitLabWidgetData {
    let calendar = Calendar.current
    let now = Date()
    let endOfToday = calendar.startOfDay(for: now)
    // Ask GitLab for up to a year. It caps to whatever it retains (typically
    // ~6–8 months). We'll shrink the grid to the earliest event we actually
    // receive so the widget isn't padded with empty weeks.
    guard let fetchFloor = calendar.date(byAdding: .day, value: -364, to: endOfToday) else {
        throw GitLabStatsError.invalidResponse
    }

    // Resolve numeric ID so we can hit /api/v4/users/:id/events — using the
    // username in the URL breaks when the username contains a dot (GitLab's
    // router treats it as a file extension).
    let userID = try await fetchAuthenticatedUser(accessToken: accessToken).id

    let isoDateFormatter = ISO8601DateFormatter()
    isoDateFormatter.formatOptions = [.withFullDate]

    // GitLab has no REST endpoint that returns the profile contribution
    // calendar. /users/:username/calendar.json exists but rejects PAT auth.
    // So we walk /api/v4/events?scope=all and, for push events, attribute one
    // contribution per individual commit (GitLab's profile calendar counts
    // commits, not pushes). Other events (issues, MRs, notes, etc.) count as
    // one contribution each.
    var counts: [Date: Int] = [:]
    var page = 1
    let maxPages = 40
    let perPage = 100

    while page <= maxPages {
        var components = makeGitLabComponents(path: "/api/v4/users/\(userID)/events")
        components.queryItems = [
            URLQueryItem(name: "after", value: isoDateFormatter.string(from: fetchFloor)),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]

        let (events, metadata): ([GitLabEventPayload], GitLabResponseMetadata) =
            try await decodeGitLabResponseWithMetadata(
                components: components,
                accessToken: accessToken,
                as: [GitLabEventPayload].self
            )

        for event in events {
            guard let createdAt = parseGitLabDate(event.created_at) else { continue }
            let day = calendar.startOfDay(for: createdAt)
            guard day >= fetchFloor, day <= endOfToday else { continue }
            counts[day, default: 0] += gitLabEventWeight(pushCommitCount: event.push_data?.commit_count)
        }

        if events.count < perPage || !metadata.hasNextPage {
            break
        }
        page += 1
    }

    return makeGitLabWidgetData(
        dailyCounts: counts,
        username: username,
        now: now,
        calendar: calendar,
        fetchFloor: fetchFloor
    )
}
