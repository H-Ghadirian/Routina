import Foundation

// Must match the Codable keys written by FocusTimerWidgetService in the main app.
struct FocusTimerWidgetData: Codable {
    let sessionID: UUID?
    let taskID: UUID?
    let taskName: String
    let taskEmoji: String
    let startedAt: Date?
    let plannedDurationSeconds: TimeInterval
    let lastUpdated: Date

    var isActive: Bool {
        sessionID != nil && startedAt != nil
    }

    var isCountUp: Bool {
        plannedDurationSeconds <= 0
    }

    var endDate: Date? {
        guard let startedAt, plannedDurationSeconds > 0 else { return nil }
        return startedAt.addingTimeInterval(plannedDurationSeconds)
    }

    static let inactive = FocusTimerWidgetData(
        sessionID: nil,
        taskID: nil,
        taskName: "No focus session",
        taskEmoji: "⏱",
        startedAt: nil,
        plannedDurationSeconds: 0,
        lastUpdated: .now
    )

    static let placeholder = FocusTimerWidgetData(
        sessionID: UUID(),
        taskID: UUID(),
        taskName: "Deep work",
        taskEmoji: "🎯",
        startedAt: .now.addingTimeInterval(-8 * 60),
        plannedDurationSeconds: 25 * 60,
        lastUpdated: .now
    )

    static func read() -> FocusTimerWidgetData {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let focus = try? JSONDecoder().decode(FocusTimerWidgetData.self, from: data) else {
            return .inactive
        }
        return focus
    }

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.ir.hamedgh.Routinam")?
            .appendingPathComponent("focus_timer_widget.json")
    }
}
