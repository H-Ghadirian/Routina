import Foundation

func fetchRepositoryStats(
    for repository: GitHubRepositoryReference,
    range: DoneChartRange,
    referenceDate: Date,
    accessToken: String?
) async throws -> GitHubRepositoryStats {
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

func validateRepository(
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
