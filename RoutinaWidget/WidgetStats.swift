import Foundation

// Must match the Codable keys written by WidgetStatsService in the main app.
struct WidgetStats: Codable {
    let tasksDueToday: Int
    let completedToday: Int
    let completedThisWeek: Int
    let totalCompleted: Int
    let currentStreak: Int
    let focusSecondsToday: TimeInterval
    let focusSessionsToday: Int
    let activeFocusIncrementStartedAt: Date?
    let lastUpdated: Date

    init(
        tasksDueToday: Int,
        completedToday: Int,
        completedThisWeek: Int,
        totalCompleted: Int,
        currentStreak: Int,
        focusSecondsToday: TimeInterval = 0,
        focusSessionsToday: Int = 0,
        activeFocusIncrementStartedAt: Date? = nil,
        lastUpdated: Date
    ) {
        self.tasksDueToday = tasksDueToday
        self.completedToday = completedToday
        self.completedThisWeek = completedThisWeek
        self.totalCompleted = totalCompleted
        self.currentStreak = currentStreak
        self.focusSecondsToday = max(0, focusSecondsToday)
        self.focusSessionsToday = max(0, focusSessionsToday)
        self.activeFocusIncrementStartedAt = activeFocusIncrementStartedAt
        self.lastUpdated = lastUpdated
    }

    var hasActiveFocusToday: Bool {
        activeFocusIncrementStartedAt != nil
    }

    func focusSecondsToday(at date: Date = .now) -> TimeInterval {
        guard let activeFocusIncrementStartedAt else {
            return focusSecondsToday
        }

        return max(0, focusSecondsToday + date.timeIntervalSince(activeFocusIncrementStartedAt))
    }

    static let placeholder = WidgetStats(
        tasksDueToday: 0,
        completedToday: 0,
        completedThisWeek: 0,
        totalCompleted: 0,
        currentStreak: 0,
        lastUpdated: .now
    )

    private enum CodingKeys: String, CodingKey {
        case tasksDueToday
        case completedToday
        case completedThisWeek
        case totalCompleted
        case currentStreak
        case focusSecondsToday
        case focusSessionsToday
        case activeFocusIncrementStartedAt
        case lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasksDueToday = try container.decode(Int.self, forKey: .tasksDueToday)
        completedToday = try container.decode(Int.self, forKey: .completedToday)
        completedThisWeek = try container.decode(Int.self, forKey: .completedThisWeek)
        totalCompleted = try container.decode(Int.self, forKey: .totalCompleted)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        focusSecondsToday = try container.decodeIfPresent(TimeInterval.self, forKey: .focusSecondsToday) ?? 0
        focusSessionsToday = try container.decodeIfPresent(Int.self, forKey: .focusSessionsToday) ?? 0
        activeFocusIncrementStartedAt = try container.decodeIfPresent(Date.self, forKey: .activeFocusIncrementStartedAt)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }

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
