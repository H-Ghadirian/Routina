import CloudKit
import Foundation
import SwiftData

enum CloudKitDirectPullService {
    private static let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: "__defaultOwner__"
    )

    struct PullResult {
        var changedRecords: [CKRecord]
        var deletedRecordIDs: [CKRecord.ID]
    }

    @MainActor
    static func pullLatestIntoLocalStore(
        containerIdentifier: String,
        modelContext: ModelContext
    ) async throws {
        let result = try await fetchZoneChanges(containerIdentifier: containerIdentifier)
        try merge(result: result, into: modelContext)
    }

    private static func fetchZoneChanges(containerIdentifier: String) async throws -> PullResult {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            func resumeIfNeeded(_ result: Result<PullResult, Error>) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = nil
            config.desiredKeys = nil

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )

            operation.recordWasChangedBlock = { _, result in
                switch result {
                case .success(let record):
                    changedRecords.append(record)
                case .failure:
                    // Keep going; one failed record should not abort the whole pull.
                    break
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deletedRecordIDs.append(recordID)
            }

            operation.recordZoneFetchResultBlock = { _, result in
                if case .failure(let error) = result {
                    resumeIfNeeded(.failure(error))
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    resumeIfNeeded(
                        .success(
                            PullResult(
                                changedRecords: changedRecords,
                                deletedRecordIDs: deletedRecordIDs
                            )
                        )
                    )
                case .failure(let error):
                    resumeIfNeeded(.failure(error))
                }
            }

            database.add(operation)
        }
    }

    @MainActor
    private static func merge(result: PullResult, into context: ModelContext) throws {
        for record in result.changedRecords {
            if let taskPayload = parseTask(from: record) {
                try upsertTask(taskPayload, in: context)
                continue
            }

            if let logPayload = parseLog(from: record) {
                try upsertLog(logPayload, in: context)
            }
        }

        for recordID in result.deletedRecordIDs {
            guard let id = UUID(uuidString: recordID.recordName) else { continue }

            let taskDescriptor = FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.id == id
                }
            )
            if let task = try context.fetch(taskDescriptor).first {
                context.delete(task)
            }

            let logDescriptor = FetchDescriptor<RoutineLog>(
                predicate: #Predicate { log in
                    log.id == id
                }
            )
            if let log = try context.fetch(logDescriptor).first {
                context.delete(log)
            }
        }

        if context.hasChanges {
            try context.save()
            NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
        }
    }

    private struct TaskPayload {
        var id: UUID
        var name: String?
        var emoji: String?
        var interval: Int16
        var lastDone: Date?
    }

    private struct LogPayload {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID
    }

    private static func parseTask(from record: CKRecord) -> TaskPayload? {
        guard isTaskRecordType(record.recordType) else { return nil }
        let id = UUID(uuidString: record.recordID.recordName)
        guard let id else { return nil }

        let intervalValue = intValue(in: record, keys: ["interval", "INTERVAL", "zinterval", "ZINTERVAL", "cd_interval"])
        let nameValue = stringValue(in: record, keys: ["name", "NAME", "zname", "ZNAME", "cd_name"])
        let emojiValue = stringValue(in: record, keys: ["emoji", "EMOJI", "zemoji", "ZEMOJI", "cd_emoji"])
        let lastDoneValue = dateValue(in: record, keys: ["lastDone", "LASTDONE", "zlastdone", "ZLASTDONE", "cd_lastdone"])

        guard intervalValue != nil || nameValue != nil || emojiValue != nil || lastDoneValue != nil else {
            return nil
        }

        return TaskPayload(
            id: id,
            name: nameValue,
            emoji: emojiValue,
            interval: Int16(clamping: intervalValue ?? 1),
            lastDone: lastDoneValue
        )
    }

    private static func parseLog(from record: CKRecord) -> LogPayload? {
        guard isLogRecordType(record.recordType) else { return nil }
        guard let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        guard let taskID = uuidValue(in: record, keys: ["taskID", "taskId", "TASKID", "ztaskid", "ZTASKID", "cd_taskid"]) else {
            return nil
        }

        let timestamp = dateValue(in: record, keys: ["timestamp", "TIMESTAMP", "ztimestamp", "ZTIMESTAMP", "cd_timestamp"])
        return LogPayload(id: id, timestamp: timestamp, taskID: taskID)
    }

    @MainActor
    private static func upsertTask(_ payload: TaskPayload, in context: ModelContext) throws {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == payloadID
            }
        )
        let normalizedIncomingName = normalizedRoutineName(payload.name)

        if let existing = try context.fetch(descriptor).first {
            if let normalizedIncomingName,
               let taskWithSameName = try task(matchingNormalizedName: normalizedIncomingName, in: context),
               taskWithSameName.id != existing.id {
                // Keep local uniqueness invariant if cloud data contains a duplicate name.
                existing.emoji = payload.emoji
                existing.interval = payload.interval
                existing.lastDone = payload.lastDone
                return
            }

            existing.name = cleanedRoutineName(payload.name)
            existing.emoji = payload.emoji
            existing.interval = payload.interval
            existing.lastDone = payload.lastDone
        } else {
            if let normalizedIncomingName,
               let taskWithSameName = try task(matchingNormalizedName: normalizedIncomingName, in: context) {
                taskWithSameName.emoji = payload.emoji
                taskWithSameName.interval = payload.interval
                taskWithSameName.lastDone = payload.lastDone
                return
            }

            context.insert(
                RoutineTask(
                    id: payload.id,
                    name: cleanedRoutineName(payload.name),
                    emoji: payload.emoji,
                    interval: payload.interval,
                    lastDone: payload.lastDone
                )
            )
        }
    }

    @MainActor
    private static func upsertLog(_ payload: LogPayload, in context: ModelContext) throws {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.id == payloadID
            }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.timestamp = payload.timestamp
            existing.taskID = payload.taskID
        } else {
            context.insert(
                RoutineLog(
                    id: payload.id,
                    timestamp: payload.timestamp,
                    taskID: payload.taskID
                )
            )
        }
    }

    private static func stringValue(in record: CKRecord, keys: [String]) -> String? {
        for key in keys {
            if let value = record[key] as? String {
                return value
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()],
               let value = record[matchedKey] as? String {
                return value
            }
        }
        return nil
    }

    private static func intValue(in record: CKRecord, keys: [String]) -> Int? {
        for key in keys {
            if let value = record[key] as? NSNumber {
                return value.intValue
            }
            if let value = record[key] as? Int {
                return value
            }
            if let value = record[key] as? Int64 {
                return Int(value)
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()],
               let number = record[matchedKey] as? NSNumber {
                return number.intValue
            }
        }
        return nil
    }

    private static func dateValue(in record: CKRecord, keys: [String]) -> Date? {
        for key in keys {
            if let value = record[key] as? Date {
                return value
            }
            if let value = record[key] as? NSDate {
                return value as Date
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()],
               let value = record[matchedKey] as? Date {
                return value
            }
        }
        return nil
    }

    private static func uuidValue(in record: CKRecord, keys: [String]) -> UUID? {
        for key in keys {
            if let uuid = record[key] as? UUID {
                return uuid
            }
            if let string = record[key] as? String, let uuid = UUID(uuidString: string) {
                return uuid
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()] {
                if let uuid = record[matchedKey] as? UUID {
                    return uuid
                }
                if let string = record[matchedKey] as? String, let uuid = UUID(uuidString: string) {
                    return uuid
                }
            }
        }
        return nil
    }

    private static func isTaskRecordType(_ recordType: String) -> Bool {
        let normalized = recordType.lowercased()
        return normalized.contains("routinetask")
            || normalized.contains("routine_task")
    }

    private static func isLogRecordType(_ recordType: String) -> Bool {
        let normalized = recordType.lowercased()
        return normalized.contains("routinelog")
            || normalized.contains("routine_log")
    }

    @MainActor
    private static func task(
        matchingNormalizedName normalizedName: String,
        in context: ModelContext
    ) throws -> RoutineTask? {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.first { task in
            normalizedRoutineName(task.name) == normalizedName
        }
    }

    private static func cleanedRoutineName(_ name: String?) -> String? {
        name?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedRoutineName(_ name: String?) -> String? {
        guard let cleaned = cleanedRoutineName(name), !cleaned.isEmpty else { return nil }
        return cleaned.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
