import Foundation

func fetchProfileStats(
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

func fetchWidgetContributions(
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
