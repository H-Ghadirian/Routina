import Foundation
import SwiftData

enum DayPlanBlockPlacementSource: String, Codable, Sendable {
    case automatic
    case manual
    case legacy
}

struct DayPlanBlock: Identifiable, Codable, Equatable, Sendable {
    static let minimumDurationMinutes = 15
    static let minimumStoredDurationMinutes = 1
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
    var placementSource: DayPlanBlockPlacementSource

    private enum CodingKeys: String, CodingKey {
        case id
        case taskID
        case dayKey
        case startMinute
        case durationMinutes
        case titleSnapshot
        case emojiSnapshot
        case createdAt
        case updatedAt
        case placementSource
    }

    init(
        id: UUID = UUID(),
        taskID: UUID,
        dayKey: String,
        startMinute: Int,
        durationMinutes: Int,
        titleSnapshot: String,
        emojiSnapshot: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        placementSource: DayPlanBlockPlacementSource = .manual,
        minimumDurationMinutes: Int = Self.minimumDurationMinutes
    ) {
        let sanitizedStartMinute = Self.clampedStartMinute(
            startMinute,
            minimumDurationMinutes: minimumDurationMinutes
        )
        self.id = id
        self.taskID = taskID
        self.dayKey = dayKey
        self.startMinute = sanitizedStartMinute
        self.durationMinutes = Self.clampedDuration(
            durationMinutes,
            startMinute: sanitizedStartMinute,
            minimumDurationMinutes: minimumDurationMinutes
        )
        self.titleSnapshot = titleSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled task"
            : titleSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        self.emojiSnapshot = emojiSnapshot?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.placementSource = placementSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            taskID: try container.decode(UUID.self, forKey: .taskID),
            dayKey: try container.decode(String.self, forKey: .dayKey),
            startMinute: try container.decode(Int.self, forKey: .startMinute),
            durationMinutes: try container.decode(Int.self, forKey: .durationMinutes),
            titleSnapshot: try container.decode(String.self, forKey: .titleSnapshot),
            emojiSnapshot: try container.decodeIfPresent(String.self, forKey: .emojiSnapshot),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            placementSource: try container.decodeIfPresent(
                DayPlanBlockPlacementSource.self,
                forKey: .placementSource
            ) ?? .legacy,
            minimumDurationMinutes: Self.minimumStoredDurationMinutes
        )
    }

    var endMinute: Int {
        min(Self.minutesPerDay, startMinute + durationMinutes)
    }

    static func clampedStartMinute(
        _ value: Int,
        minimumDurationMinutes: Int = Self.minimumDurationMinutes
    ) -> Int {
        let minimumDurationMinutes = max(Self.minimumStoredDurationMinutes, minimumDurationMinutes)
        return min(max(value, 0), minutesPerDay - minimumDurationMinutes)
    }

    static func clampedDuration(
        _ value: Int,
        startMinute: Int,
        minimumDurationMinutes: Int = Self.minimumDurationMinutes
    ) -> Int {
        let minimumDurationMinutes = max(Self.minimumStoredDurationMinutes, minimumDurationMinutes)
        let sanitizedStartMinute = clampedStartMinute(
            startMinute,
            minimumDurationMinutes: minimumDurationMinutes
        )
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
    var placementSourceRawValue: String = DayPlanBlockPlacementSource.legacy.rawValue

    init(
        id: UUID = UUID(),
        taskID: UUID,
        dayKey: String,
        startMinute: Int,
        durationMinutes: Int,
        titleSnapshot: String,
        emojiSnapshot: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        placementSource: DayPlanBlockPlacementSource = .manual
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
                updatedAt: updatedAt,
                placementSource: placementSource,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
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
            updatedAt: block.updatedAt,
            placementSource: block.placementSource
        )
    }

    var placementSource: DayPlanBlockPlacementSource {
        get { DayPlanBlockPlacementSource(rawValue: placementSourceRawValue) ?? .legacy }
        set { placementSourceRawValue = newValue.rawValue }
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
            updatedAt: updatedAt,
            placementSource: placementSource,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
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
        placementSource = block.placementSource
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

        let undoManager = MainActor.assumeIsolated {
            RoutinaUndoSupport.currentUndoManager
        }
        let didDisableUndo = MainActor.assumeIsolated {
            guard let undoManager,
                  undoManager.isUndoRegistrationEnabled
            else { return false }
            undoManager.disableUndoRegistration()
            return true
        }
        defer {
            if didDisableUndo {
                MainActor.assumeIsolated {
                    undoManager?.enableUndoRegistration()
                }
            }
        }

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

    @discardableResult
    static func deleteBlocks(
        forTaskIDs taskIDs: Set<UUID>,
        context: ModelContext
    ) throws -> Int {
        guard !taskIDs.isEmpty else { return 0 }

        migrateLegacyDefaultsIfNeeded(to: context)

        let records = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
        var deletedCount = 0
        for record in records where taskIDs.contains(record.taskID) {
            context.delete(record)
            deletedCount += 1
        }
        return deletedCount
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
        var blocksByID: [UUID: DayPlanBlock] = [:]

        for block in blocks {
            let sanitizedBlock = DayPlanBlock(
                id: block.id,
                taskID: block.taskID,
                dayKey: dayKey,
                startMinute: block.startMinute,
                durationMinutes: block.durationMinutes,
                titleSnapshot: block.titleSnapshot,
                emojiSnapshot: block.emojiSnapshot,
                createdAt: block.createdAt,
                updatedAt: block.updatedAt,
                placementSource: block.placementSource,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
            guard let existingBlock = blocksByID[sanitizedBlock.id] else {
                blocksByID[sanitizedBlock.id] = sanitizedBlock
                continue
            }

            if shouldKeep(sanitizedBlock, over: existingBlock) {
                blocksByID[sanitizedBlock.id] = sanitizedBlock
            }
        }

        var blocksByPlacement: [DayPlanBlockPlacementKey: DayPlanBlock] = [:]
        for block in blocksByID.values {
            let placementKey = DayPlanBlockPlacementKey(block: block)
            guard let existingBlock = blocksByPlacement[placementKey] else {
                blocksByPlacement[placementKey] = block
                continue
            }

            if shouldKeep(block, over: existingBlock) {
                blocksByPlacement[placementKey] = block
            }
        }

        return blocksByPlacement.values.sorted {
            if $0.startMinute != $1.startMinute {
                return $0.startMinute < $1.startMinute
            }
            return $0.createdAt < $1.createdAt
        }
    }

    private static func shouldKeep(_ candidate: DayPlanBlock, over existing: DayPlanBlock) -> Bool {
        if candidate.updatedAt != existing.updatedAt {
            return candidate.updatedAt > existing.updatedAt
        }
        if candidate.createdAt != existing.createdAt {
            return candidate.createdAt > existing.createdAt
        }
        if candidate.durationMinutes != existing.durationMinutes {
            return candidate.durationMinutes > existing.durationMinutes
        }
        return candidate.id.uuidString > existing.id.uuidString
    }
}

private struct DayPlanBlockPlacementKey: Hashable {
    var taskID: UUID
    var startMinute: Int
    var durationMinutes: Int

    init(block: DayPlanBlock) {
        taskID = block.taskID
        startMinute = block.startMinute
        durationMinutes = block.durationMinutes
    }
}

enum DayPlanAutomaticBlockSync {
    private struct Placement: Equatable {
        enum Kind: Equatable {
            case scheduled
            case availabilityWindow
        }

        var kind: Kind
        var startMinute: Int
        var durationMinutes: Int
    }

    @discardableResult
    static func rebaseAutomaticallyScheduledBlocks(
        from previousTask: RoutineTask,
        to updatedTask: RoutineTask,
        calendar: Calendar,
        context: ModelContext
    ) throws -> Bool {
        guard previousTask.id == updatedTask.id else { return false }

        let taskID = updatedTask.id
        let records = try context.fetch(
            FetchDescriptor<DayPlanBlockRecord>(
                predicate: #Predicate<DayPlanBlockRecord> { record in
                    record.taskID == taskID
                }
            )
        )
        var didChange = false

        for record in records {
            guard let date = date(forDayKey: record.dayKey, calendar: calendar),
                  let previousPlacement = automaticPlacement(
                      for: previousTask,
                      on: date,
                      calendar: calendar
                  ),
                  isAutomaticallyManaged(record, matching: previousPlacement)
            else {
                continue
            }

            guard let updatedPlacement = scheduledPlacement(
                for: updatedTask,
                on: date,
                calendar: calendar
            ),
            !updatedTask.isArchived(
                referenceDate: date,
                calendar: calendar
            ) else {
                context.delete(record)
                didChange = true
                continue
            }

            record.apply(
                DayPlanBlock(
                    id: record.id,
                    taskID: record.taskID,
                    dayKey: record.dayKey,
                    startMinute: updatedPlacement.startMinute,
                    durationMinutes: updatedPlacement.durationMinutes,
                    titleSnapshot: record.titleSnapshot,
                    emojiSnapshot: record.emojiSnapshot,
                    createdAt: record.createdAt,
                    updatedAt: Date(),
                    placementSource: .automatic,
                    minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
                )
            )
            didChange = true
        }

        return didChange
    }

    private static func isAutomaticallyManaged(
        _ record: DayPlanBlockRecord,
        matching previousPlacement: Placement
    ) -> Bool {
        switch record.placementSource {
        case .automatic:
            return true
        case .manual:
            return false
        case .legacy:
            let matchesPreviousPlacement = record.startMinute == previousPlacement.startMinute
                && record.durationMinutes == previousPlacement.durationMinutes
            return matchesPreviousPlacement || record.createdAt == record.updatedAt
        }
    }

    private static func automaticPlacement(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> Placement? {
        if let scheduled = scheduledBlock(for: task, on: date, calendar: calendar) {
            return scheduled
        }

        guard let window = availabilityWindow(for: task, on: date, calendar: calendar) else {
            return nil
        }
        return window
    }

    private static func scheduledPlacement(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> Placement? {
        guard let placement = scheduledBlock(for: task, on: date, calendar: calendar) else {
            return nil
        }
        return placement.kind == .scheduled ? placement : nil
    }

    private static func scheduledBlock(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> Placement? {
        guard !task.isAllDay else { return nil }

        if task.isOneOffTask {
            if isDateWithinAvailabilityDateBounds(date, for: task, calendar: calendar) {
                if let timeRange = task.recurrenceRule.timeRange,
                   task.recurrenceTimeRangeRole == .scheduledBlock {
                    let startDate = timeRange.startDate(on: date, calendar: calendar)
                    let endDate = timeRange.endDate(on: date, calendar: calendar)
                    return placement(
                        kind: .scheduled,
                        startDate: startDate,
                        durationMinutes: availabilityWindowDuration(start: startDate, end: endDate),
                        task: task,
                        calendar: calendar
                    )
                }
                if let timeOfDay = task.recurrenceRule.timeOfDay {
                    return placement(
                        kind: .scheduled,
                        startDate: timeOfDay.date(on: date, calendar: calendar),
                        durationMinutes: nil,
                        task: task,
                        calendar: calendar
                    )
                }
            }

            guard let deadline = task.deadline,
                  calendar.isDate(deadline, inSameDayAs: date),
                  hasExplicitTime(deadline, calendar: calendar) else {
                return nil
            }
            return placement(
                kind: .scheduled,
                startDate: deadline,
                durationMinutes: nil,
                task: task,
                calendar: calendar
            )
        }

        guard let occurrence = RoutineDateMath.scheduledOccurrence(
            for: task,
            on: date,
            calendar: calendar
        ) else {
            return nil
        }
        if let timeRange = task.recurrenceRule.timeRange {
            guard task.recurrenceTimeRangeRole == .scheduledBlock else { return nil }
            let rangeStart = timeRange.startDate(on: occurrence, calendar: calendar)
            return placement(
                kind: .scheduled,
                startDate: rangeStart,
                durationMinutes: availabilityWindowDuration(
                    start: rangeStart,
                    end: timeRange.endDate(on: rangeStart, calendar: calendar)
                ),
                task: task,
                calendar: calendar
            )
        }
        return placement(
            kind: .scheduled,
            startDate: occurrence,
            durationMinutes: nil,
            task: task,
            calendar: calendar
        )
    }

    private static func availabilityWindow(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> Placement? {
        guard !task.isAllDay,
              task.recurrenceTimeRangeRole == .availability,
              let timeRange = task.recurrenceRule.timeRange else {
            return nil
        }

        if task.isOneOffTask {
            guard isDateWithinAvailabilityDateBounds(date, for: task, calendar: calendar) else {
                return nil
            }
            let startDate = timeRange.startDate(on: date, calendar: calendar)
            let endDate = timeRange.endDate(on: date, calendar: calendar)
            return placement(
                kind: .availabilityWindow,
                startDate: startDate,
                durationMinutes: availabilityWindowDuration(start: startDate, end: endDate),
                task: task,
                calendar: calendar
            )
        }

        guard let occurrence = RoutineDateMath.scheduledOccurrence(
            for: task,
            on: date,
            calendar: calendar
        ) else {
            return nil
        }
        let rangeStart = timeRange.startDate(on: occurrence, calendar: calendar)
        let windowDuration = availabilityWindowDuration(
            start: rangeStart,
            end: timeRange.endDate(on: rangeStart, calendar: calendar)
        )
        return placement(
            kind: .availabilityWindow,
            startDate: rangeStart,
            durationMinutes: task.estimatedDurationMinutes ?? windowDuration,
            task: task,
            calendar: calendar
        )
    }

    private static func placement(
        kind: Placement.Kind,
        startDate: Date,
        durationMinutes: Int?,
        task: RoutineTask,
        calendar: Calendar
    ) -> Placement {
        let startMinute = startMinute(for: startDate, calendar: calendar)
        return Placement(
            kind: kind,
            startMinute: startMinute,
            durationMinutes: DayPlanBlock.clampedDuration(
                durationMinutes ?? task.estimatedDurationMinutes ?? 60,
                startMinute: startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
        )
    }

    private static func date(forDayKey dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
        )
    }

    private static func startMinute(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
    }

    private static func availabilityWindowDuration(start: Date, end: Date) -> Int? {
        guard end > start else { return nil }
        return max(
            Int((end.timeIntervalSince(start) / 60).rounded()),
            DayPlanBlock.minimumDurationMinutes
        )
    }

    private static func isDateWithinAvailabilityDateBounds(
        _ date: Date,
        for task: RoutineTask,
        calendar: Calendar
    ) -> Bool {
        guard let availabilityStartDate = task.availabilityStartDate else { return false }
        let day = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: availabilityStartDate)
        let endDay = calendar.startOfDay(for: task.availabilityEndDate ?? availabilityStartDate)
        return day >= startDay && day <= endDay
    }

    private static func hasExplicitTime(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return (components.hour ?? 0) != 0
            || (components.minute ?? 0) != 0
            || (components.second ?? 0) != 0
            || (components.nanosecond ?? 0) != 0
    }
}
