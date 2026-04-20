import Foundation

// Must match the Codable keys written by WidgetStatsService in the main app.
struct WidgetStats: Codable {
    let tasksDueToday: Int
    let completedToday: Int
    let completedThisWeek: Int
    let totalCompleted: Int
    let currentStreak: Int
    let lastUpdated: Date

    static let placeholder = WidgetStats(
        tasksDueToday: 0,
        completedToday: 0,
        completedThisWeek: 0,
        totalCompleted: 0,
        currentStreak: 0,
        lastUpdated: .now
    )

    static func read() -> WidgetStats {
        guard let url = statsFileURL,
              let data = try? Data(contentsOf: url),
              let stats = try? JSONDecoder().decode(WidgetStats.self, from: data) else {
            return .placeholder
        }
        return stats
    }

    private static var statsFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.ir.hamedgh.Routinam")?
            .appendingPathComponent("widget_stats.json")
    }
}
