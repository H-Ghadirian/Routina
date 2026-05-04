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
        days.compactMap { day -> (Date, Int)? in
            guard let date = formatter.date(from: day.date) else { return nil }
            let normalized = calendar.startOfDay(for: date)
            guard normalized >= calendar.startOfDay(for: window.startDate),
                  normalized <= calendar.startOfDay(for: window.endDate)
            else {
                return nil
            }
            return (normalized, day.contributionCount)
        },
        uniquingKeysWith: { first, _ in first }
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

private func fetchWidgetContributions(
    accessToken: String,
    fallbackLogin: String?
) async throws -> GitHubWidgetData {
    let calendar = Calendar.current
    let now = Date()
    let from = calendar.date(byAdding: .day, value: -364, to: calendar.startOfDay(for: now)) ?? now

    let variables = [
        "from": makeGitHubDateTimeString(from),
        "to": makeGitHubDateTimeString(now)
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

    let calendarPayload = payload.viewer.contributionsCollection.contributionCalendar
    let weeks = calendarPayload.weeks.map { week in
        GitHubWidgetData.Week(
            days: week.contributionDays.map { day in
                GitHubWidgetData.Week.Day(date: day.date, count: day.contributionCount)
            }
        )
    }

    let login = payload.viewer.login.isEmpty ? (fallbackLogin ?? "viewer") : payload.viewer.login
    return GitHubWidgetData(
        login: login,
        weeks: weeks,
        totalContributions: calendarPayload.totalContributions,
        fetchedAt: now
    )
}
