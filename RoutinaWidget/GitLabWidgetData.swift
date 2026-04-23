import Foundation

// Must match Codable keys written by GitLabWidgetService in the main app.
struct GitLabWidgetData: Codable {
    struct Week: Codable {
        struct Day: Codable {
            let date: String
            let count: Int
        }
        let days: [Day]
    }

    let username: String
    let weeks: [Week]
    let totalContributions: Int
    let fetchedAt: Date

    static func read() -> GitLabWidgetData? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url)
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(GitLabWidgetData.self, from: data)
    }

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.ir.hamedgh.Routinam")?
            .appendingPathComponent("gitlab_widget.json")
    }
}
