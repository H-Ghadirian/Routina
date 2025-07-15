import Foundation
import Security

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
    guard let url = try? gitLabUserStoreURL(),
          FileManager.default.fileExists(atPath: url.path),
          let data = try? Data(contentsOf: url),
          let stored = try? JSONDecoder().decode(StoredGitLabUser.self, from: data)
    else {
        return nil
    }
    return stored.username
}

private func saveStoredUsername(_ username: String) throws {
    let url = try gitLabUserStoreURL()
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let data = try JSONEncoder().encode(StoredGitLabUser(username: username))
    try data.write(to: url, options: [.atomic])
}

private func clearStoredUsername() throws {
    let url = try gitLabUserStoreURL()
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    try FileManager.default.removeItem(at: url)
}

private func gitLabUserStoreURL() throws -> URL {
    let applicationSupportDirectory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let storesDirectory = applicationSupportDirectory.appendingPathComponent("RoutinaData", isDirectory: true)
    return storesDirectory.appendingPathComponent(GitLabStore.usernameFilename)
}

private func storedAccessToken() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: GitLabStore.accessTokenService,
        kSecAttrAccount as String: GitLabStore.accessTokenAccount,
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
        kSecAttrService as String: GitLabStore.accessTokenService,
        kSecAttrAccount as String: GitLabStore.accessTokenAccount
    ]

    let attributes: [String: Any] = [kSecValueData as String: data]
    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess { return }

    var addQuery = baseQuery
    addQuery[kSecValueData as String] = data
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
        throw GitLabStatsError.networkFailure("The GitLab token could not be stored securely.")
    }
}

private func clearAccessToken() throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: GitLabStore.accessTokenService,
        kSecAttrAccount as String: GitLabStore.accessTokenAccount
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
        throw GitLabStatsError.networkFailure("The saved GitLab token could not be removed.")
    }
}

// MARK: - API

private struct GitLabUserPayload: Decodable {
    let id: Int
    let username: String
}

private struct GitLabEventPayload: Decodable {
    struct PushData: Decodable {
        let commit_count: Int?
    }
    let created_at: String
    let action_name: String?
    let push_data: PushData?
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

/// Builds the widget payload from pre-aggregated per-day counts. The grid is
/// packed from the earliest day with activity (clamped at `fetchFloor`) to
/// today, so there are no empty leading weeks before GitLab's retention
/// cutoff. Total contributions count every value in `dailyCounts`.
func makeGitLabWidgetData(
    dailyCounts: [Date: Int],
    username: String,
    now: Date,
    calendar: Calendar,
    fetchFloor: Date
) -> GitLabWidgetData {
    let endOfToday = calendar.startOfDay(for: now)
    let earliestEvent = dailyCounts.keys.min() ?? fetchFloor
    let startDay = max(earliestEvent, fetchFloor)
    let weeks = buildWeeks(
        counts: dailyCounts,
        startDay: startDay,
        endOfToday: endOfToday,
        calendar: calendar
    )
    let total = dailyCounts.values.reduce(0, +)
    return GitLabWidgetData(
        username: username,
        weeks: weeks,
        totalContributions: total,
        fetchedAt: now
    )
}

/// Weight a single event for the contribution grid: push events count their
/// individual commits (matching GitLab's own profile calendar), everything
/// else (issues, MRs, comments) counts as 1.
func gitLabEventWeight(pushCommitCount: Int?) -> Int {
    if let commitCount = pushCommitCount, commitCount > 0 {
        return commitCount
    }
    return 1
}

func buildWeeks(
    counts: [Date: Int],
    startDay: Date,
    endOfToday: Date,
    calendar: Calendar
) -> [GitLabWidgetData.Week] {
    let dayStringFormatter = DateFormatter()
    dayStringFormatter.calendar = calendar
    dayStringFormatter.locale = Locale(identifier: "en_US_POSIX")
    dayStringFormatter.timeZone = calendar.timeZone
    dayStringFormatter.dateFormat = "yyyy-MM-dd"

    // GitHub weeks are Sun–Sat; mirror that. Weekday 1 = Sunday in Gregorian.
    var gridCalendar = calendar
    gridCalendar.firstWeekday = 1
    let startWeekday = gridCalendar.component(.weekday, from: startDay)
    let leadingEmptyDays = startWeekday - 1

    guard let gridStart = gridCalendar.date(
        byAdding: .day,
        value: -leadingEmptyDays,
        to: startDay
    ) else {
        return []
    }

    var weeks: [GitLabWidgetData.Week] = []
    var dayCursor = gridStart
    while dayCursor <= endOfToday {
        var days: [GitLabWidgetData.Week.Day] = []
        for _ in 0..<7 {
            let count = (dayCursor >= startDay && dayCursor <= endOfToday)
                ? (counts[dayCursor] ?? 0)
                : 0
            days.append(
                GitLabWidgetData.Week.Day(
                    date: dayStringFormatter.string(from: dayCursor),
                    count: count
                )
            )
            guard let next = gridCalendar.date(byAdding: .day, value: 1, to: dayCursor) else {
                return weeks
            }
            dayCursor = next
        }
        weeks.append(GitLabWidgetData.Week(days: days))
    }
    return weeks
}

func parseGitLabDate(_ string: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: string) { return date }

    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: string)
}

private struct GitLabResponseMetadata: Sendable {
    let hasNextPage: Bool
}

private func decodeGitLabResponse<T: Decodable>(
    components: URLComponents,
    accessToken: String
) async throws -> T {
    let (value, _) = try await decodeGitLabResponseWithMetadata(
        components: components,
        accessToken: accessToken,
        as: T.self
    )
    return value
}

private func decodeGitLabResponseWithMetadata<T: Decodable>(
    components: URLComponents,
    accessToken: String,
    as type: T.Type
) async throws -> (T, GitLabResponseMetadata) {
    guard let url = components.url else {
        throw GitLabStatsError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Routina", forHTTPHeaderField: "User-Agent")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitLabStatsError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let value = try decoder.decode(type, from: data)
            let nextPage = httpResponse.value(forHTTPHeaderField: "X-Next-Page") ?? ""
            let hasNext = !nextPage.trimmingCharacters(in: .whitespaces).isEmpty
            return (value, GitLabResponseMetadata(hasNextPage: hasNext))
        case 401:
            throw GitLabStatsError.unauthorized
        case 403:
            throw GitLabStatsError.unauthorized
        case 429:
            throw GitLabStatsError.rateLimited
        default:
            throw GitLabStatsError.invalidResponse
        }
    } catch let error as GitLabStatsError {
        throw error
    } catch {
        throw GitLabStatsError.networkFailure(error.localizedDescription)
    }
}

private func makeGitLabComponents(path: String) -> URLComponents {
    var components = URLComponents()
    components.scheme = "https"
    components.host = GitLabStore.host
    components.path = path
    return components
}
