import Foundation

struct GitHubCommitPageEntry: Decodable {
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

struct GitHubCommitAggregate: Sendable {
    let date: Date
    let authorKey: String
}

struct GitHubSearchResult: Decodable {
    let totalCount: Int

    private enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
    }
}

struct GitHubRepositoryPayload: Decodable {
    let fullName: String

    private enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}

struct GitHubGraphQLRequest: Encodable {
    let query: String
    let variables: [String: String]
}

struct GitHubGraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GitHubGraphQLError]?
}

struct GitHubGraphQLError: Decodable {
    let message: String
}

struct GitHubViewerLoginPayload: Decodable {
    struct ViewerPayload: Decodable {
        let login: String
    }

    let viewer: ViewerPayload
}

struct GitHubViewerContributionsPayload: Decodable {
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
