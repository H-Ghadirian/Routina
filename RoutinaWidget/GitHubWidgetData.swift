import Foundation

// Must match Codable keys written by GitHubWidgetService in the main app.
struct GitHubWidgetData: Codable {
    struct Week: Codable {
        struct Day: Codable {
            let date: String
            let count: Int
        }
        let days: [Day]
    }

    let login: String
    let weeks: [Week]
    let totalContributions: Int
    let fetchedAt: Date

    static func read() -> GitHubWidgetData? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url)
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(GitHubWidgetData.self, from: data)
    }

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.ir.hamedgh.Routinam")?
            .appendingPathComponent("github_widget.json")
    }
}
