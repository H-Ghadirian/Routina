import Foundation
import SwiftData

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

@Model
final class DayPlanBlockRecord {
    var id: UUID = UUID()
    var taskID: UUID = UUID()
    var dayKey: String = ""
    var startMinute: Int = 0
    var durationMinutes: Int = DayPlanBlock.minimumDurationMinutes
    var titleSnapshot: String = "Untitled task"
    var emojiSnapshot: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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
        apply(
            DayPlanBlock(
                id: id,
                taskID: taskID,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: titleSnapshot,
                emojiSnapshot: emojiSnapshot,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        )
    }

    convenience init(block: DayPlanBlock) {
        self.init(
            id: block.id,
            taskID: block.taskID,
            dayKey: block.dayKey,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes,
            titleSnapshot: block.titleSnapshot,
            emojiSnapshot: block.emojiSnapshot,
            createdAt: block.createdAt,
            updatedAt: block.updatedAt
        )
    }

    var detachedBlock: DayPlanBlock {
        DayPlanBlock(
            id: id,
            taskID: taskID,
            dayKey: dayKey,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            titleSnapshot: titleSnapshot,
            emojiSnapshot: emojiSnapshot,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(_ block: DayPlanBlock) {
        id = block.id
        taskID = block.taskID
        dayKey = block.dayKey
        startMinute = block.startMinute
        durationMinutes = block.durationMinutes
        titleSnapshot = block.titleSnapshot
        emojiSnapshot = block.emojiSnapshot
        createdAt = block.createdAt
        updatedAt = block.updatedAt
    }
}

enum DayPlanStorage {
    private static let keyPrefix = "dayPlan.blocks."
    private static let swiftDataMigrationKey = "dayPlan.swiftDataMigrationComplete"

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
        context: ModelContext
    ) -> [DayPlanBlock] {
        let dayKey = dayKey(for: date, calendar: calendar)
        return loadBlocks(forDayKey: dayKey, context: context)
    }

    static func loadBlocks(
        forDayKey dayKey: String,
        context: ModelContext
    ) -> [DayPlanBlock] {
        migrateLegacyDefaultsIfNeeded(to: context)

        do {
            let records = try context.fetch(recordsDescriptor(forDayKey: dayKey))
            return sanitized(records.map(\.detachedBlock), dayKey: dayKey)
        } catch {
            NSLog("Failed to load day plan blocks for \(dayKey): \(error.localizedDescription)")
            return []
        }
    }

    static func saveBlocks(
        _ blocks: [DayPlanBlock],
        for date: Date,
        calendar: Calendar = .current,
        context: ModelContext
    ) {
        let dayKey = dayKey(for: date, calendar: calendar)
        saveBlocks(blocks, forDayKey: dayKey, context: context)
    }

    static func saveBlocks(
        _ blocks: [DayPlanBlock],
        forDayKey dayKey: String,
        context: ModelContext
    ) {
        let blocks = sanitized(blocks, dayKey: dayKey)

        do {
            let records = try context.fetch(recordsDescriptor(forDayKey: dayKey))
            var recordsByID: [UUID: DayPlanBlockRecord] = [:]
            for record in records {
                if recordsByID[record.id] == nil {
                    recordsByID[record.id] = record
                } else {
                    context.delete(record)
                }
            }
            let blockIDs = Set(blocks.map(\.id))

            for record in recordsByID.values where !blockIDs.contains(record.id) {
                context.delete(record)
            }

            for block in blocks {
                if let record = recordsByID.removeValue(forKey: block.id) {
                    record.apply(block)
                } else {
                    context.insert(DayPlanBlockRecord(block: block))
                }
            }

            try context.save()
        } catch {
            NSLog("Failed to save day plan blocks for \(dayKey): \(error.localizedDescription)")
        }
    }

    private static func migrateLegacyDefaultsIfNeeded(
        to context: ModelContext,
        defaults: UserDefaults = SharedDefaults.app
    ) {
        guard !defaults.bool(forKey: swiftDataMigrationKey) else { return }

        let legacyDayKeys = defaults.dictionaryRepresentation().keys.compactMap { key -> String? in
            guard key.hasPrefix(keyPrefix) else { return nil }
            return String(key.dropFirst(keyPrefix.count))
        }

        guard !legacyDayKeys.isEmpty else {
            defaults.set(true, forKey: swiftDataMigrationKey)
            return
        }

        do {
            for dayKey in legacyDayKeys {
                let legacyBlocks = legacyLoadBlocks(forDayKey: dayKey, defaults: defaults)
                guard !legacyBlocks.isEmpty else { continue }

                let existingRecords = try context.fetch(recordsDescriptor(forDayKey: dayKey))
                let existingIDs = Set(existingRecords.map(\.id))

                for block in legacyBlocks where !existingIDs.contains(block.id) {
                    context.insert(DayPlanBlockRecord(block: block))
                }
            }

            try context.save()
            defaults.set(true, forKey: swiftDataMigrationKey)
        } catch {
            NSLog("Failed to migrate day plan blocks to SwiftData: \(error.localizedDescription)")
        }
    }

    private static func recordsDescriptor(forDayKey dayKey: String) -> FetchDescriptor<DayPlanBlockRecord> {
        FetchDescriptor<DayPlanBlockRecord>(
            predicate: #Predicate<DayPlanBlockRecord> { record in
                record.dayKey == dayKey
            },
            sortBy: [
                SortDescriptor(\.startMinute),
                SortDescriptor(\.createdAt)
            ]
        )
    }

    private static func legacyLoadBlocks(
        forDayKey dayKey: String,
        defaults: UserDefaults
    ) -> [DayPlanBlock] {
        guard let data = defaults.data(forKey: storageKey(for: dayKey)),
              let decoded = try? JSONDecoder().decode([DayPlanBlock].self, from: data) else {
            return []
        }

        return sanitized(decoded, dayKey: dayKey)
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
