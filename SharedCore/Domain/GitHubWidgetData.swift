import Foundation

struct GitHubWidgetData: Codable, Sendable {
    struct Week: Codable, Sendable {
        struct Day: Codable, Sendable {
            let date: String
            let count: Int
        }
        let days: [Day]
    }

    let login: String
    let weeks: [Week]
    let totalContributions: Int
    let fetchedAt: Date
}
