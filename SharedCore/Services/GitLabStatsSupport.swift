import Foundation

struct GitLabUserPayload: Decodable {
    let id: Int
    let username: String
}

struct GitLabEventPayload: Decodable {
    struct PushData: Decodable {
        let commit_count: Int?
    }

    let created_at: String
    let action_name: String?
    let push_data: PushData?
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

    // GitHub weeks are Sun-Sat; mirror that. Weekday 1 = Sunday in Gregorian.
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

struct GitLabResponseMetadata: Sendable {
    let hasNextPage: Bool
}

func decodeGitLabResponse<T: Decodable>(
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

func decodeGitLabResponseWithMetadata<T: Decodable>(
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

func makeGitLabComponents(path: String) -> URLComponents {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "gitlab.com"
    components.path = path
    return components
}
