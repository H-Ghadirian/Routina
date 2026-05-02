import Foundation

struct DayPlanBlock: Identifiable, Codable, Equatable, Sendable {
    static let minimumDurationMinutes = 15
    static let minutesPerDay = 24 * 60

    var id: UUID
    var taskID: UUID
    var dayKey: String
    var startMinute: Int
    var durationMinutes: Int
    var titleSnapshot: String
    var emojiSnapshot: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        taskID: UUID,
        dayKey: String,
        startMinute: Int,
        durationMinutes: Int,
        titleSnapshot: String,
        emojiSnapshot: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let sanitizedStartMinute = Self.clampedStartMinute(startMinute)
        self.id = id
        self.taskID = taskID
        self.dayKey = dayKey
        self.startMinute = sanitizedStartMinute
        self.durationMinutes = Self.clampedDuration(durationMinutes, startMinute: sanitizedStartMinute)
        self.titleSnapshot = titleSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled task"
            : titleSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        self.emojiSnapshot = emojiSnapshot?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var endMinute: Int {
        min(Self.minutesPerDay, startMinute + durationMinutes)
    }

    static func clampedStartMinute(_ value: Int) -> Int {
        min(max(value, 0), minutesPerDay - minimumDurationMinutes)
    }

    static func clampedDuration(_ value: Int, startMinute: Int) -> Int {
        let sanitizedStartMinute = clampedStartMinute(startMinute)
        let remainingMinutes = max(minimumDurationMinutes, minutesPerDay - sanitizedStartMinute)
        return min(max(value, minimumDurationMinutes), remainingMinutes)
    }
}

enum DayPlanStorage {
    private static let keyPrefix = "dayPlan.blocks."

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 1,
            components.day ?? 1
        )
    }

    static func loadBlocks(
        for date: Date,
        calendar: Calendar = .current,
        defaults: UserDefaults = SharedDefaults.app
    ) -> [DayPlanBlock] {
        let dayKey = dayKey(for: date, calendar: calendar)
        guard let data = defaults.data(forKey: storageKey(for: dayKey)),
              let decoded = try? JSONDecoder().decode([DayPlanBlock].self, from: data) else {
            return []
        }

        return sanitized(decoded, dayKey: dayKey)
    }

    static func saveBlocks(
        _ blocks: [DayPlanBlock],
        for date: Date,
        calendar: Calendar = .current,
        defaults: UserDefaults = SharedDefaults.app
    ) {
        let dayKey = dayKey(for: date, calendar: calendar)
        let blocks = sanitized(blocks, dayKey: dayKey)
        let key = storageKey(for: dayKey)

        guard !blocks.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(blocks) else { return }
        defaults.set(data, forKey: key)
    }

    private static func storageKey(for dayKey: String) -> String {
        keyPrefix + dayKey
    }

    private static func sanitized(_ blocks: [DayPlanBlock], dayKey: String) -> [DayPlanBlock] {
        blocks
            .map { block in
                DayPlanBlock(
                    id: block.id,
                    taskID: block.taskID,
                    dayKey: dayKey,
                    startMinute: block.startMinute,
                    durationMinutes: block.durationMinutes,
                    titleSnapshot: block.titleSnapshot,
                    emojiSnapshot: block.emojiSnapshot,
                    createdAt: block.createdAt,
                    updatedAt: block.updatedAt
                )
            }
            .sorted {
                if $0.startMinute != $1.startMinute {
                    return $0.startMinute < $1.startMinute
                }
                return $0.createdAt < $1.createdAt
            }
    }
}
