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

    @MainActor
    static func mergeForTesting(
        _ result: PullResult,
        into context: ModelContext
    ) throws {
        try merge(result: result, into: context)
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
        var mergedTaskIDs: [UUID: UUID] = [:]
        var placePayloads: [PlacePayload] = []
        var taskPayloads: [TaskPayload] = []
        var logPayloads: [LogPayload] = []

        for record in result.changedRecords {
            if let placePayload = parsePlace(from: record) {
                placePayloads.append(placePayload)
                continue
            }

            if let taskPayload = parseTask(from: record) {
                taskPayloads.append(taskPayload)
                continue
            }

            if let logPayload = parseLog(from: record) {
                logPayloads.append(logPayload)
            }
        }

        for placePayload in placePayloads {
            try upsertPlace(placePayload, in: context)
        }

        for taskPayload in taskPayloads {
            mergedTaskIDs[taskPayload.id] = try upsertTask(taskPayload, in: context)
        }

        for logPayload in logPayloads {
            var canonicalPayload = logPayload
            canonicalPayload.taskID = mergedTaskIDs[logPayload.taskID]
                ?? canonicalTaskID(for: logPayload.taskID, in: context)
            try upsertLog(canonicalPayload, in: context)
        }

        for (sourceTaskID, targetTaskID) in mergedTaskIDs where sourceTaskID != targetTaskID {
            try migrateLogs(from: sourceTaskID, to: targetTaskID, in: context)
        }

        for recordID in result.deletedRecordIDs {
            guard let id = UUID(uuidString: recordID.recordName) else { continue }
            if let targetTaskID = mergedTaskIDs[id], targetTaskID != id {
                continue
            }

            let placeDescriptor = FetchDescriptor<RoutinePlace>(
                predicate: #Predicate { place in
                    place.id == id
                }
            )
            if let place = try context.fetch(placeDescriptor).first {
                context.delete(place)
                try clearPlaceReference(placeID: id, in: context)
                continue
            }

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

        try deduplicateLogs(in: context)

        if context.hasChanges {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    private struct TaskPayload {
        var id: UUID
        var name: String?
        var emoji: String?
        var placeID: UUID?
        var tags: [String]?
        var steps: [RoutineStep]?
        var checklistItems: [RoutineChecklistItem]?
        var scheduleMode: RoutineScheduleMode?
        var interval: Int16
        var lastDone: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var pinnedAt: Date?
        var completedStepCount: Int16
        var sequenceStartedAt: Date?
    }

    private struct PlacePayload {
        var id: UUID
        var name: String?
        var latitude: Double
        var longitude: Double
        var radiusMeters: Double
        var createdAt: Date?
    }

    private struct LogPayload {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID
    }

    private static func parsePlace(from record: CKRecord) -> PlacePayload? {
        guard isPlaceRecordType(record.recordType) else { return nil }
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let nameValue = stringValue(in: record, keys: ["name", "NAME", "zname", "ZNAME", "cd_name"])
        guard
            let latitudeValue = doubleValue(in: record, keys: ["latitude", "LATITUDE", "zlatitude", "ZLATITUDE", "cd_latitude"]),
            let longitudeValue = doubleValue(in: record, keys: ["longitude", "LONGITUDE", "zlongitude", "ZLONGITUDE", "cd_longitude"])
        else {
            return nil
        }

        let radiusValue = doubleValue(
            in: record,
            keys: ["radiusMeters", "RADIUSMETERS", "zradiusmeters", "ZRADIUSMETERS", "cd_radiusmeters"]
        ) ?? 150
        let createdAtValue = dateValue(
            in: record,
            keys: ["createdAt", "CREATEDAT", "zcreatedat", "ZCREATEDAT", "cd_createdat"]
        )

        return PlacePayload(
            id: id,
            name: nameValue,
            latitude: latitudeValue,
            longitude: longitudeValue,
            radiusMeters: radiusValue,
            createdAt: createdAtValue
        )
    }

    private static func parseTask(from record: CKRecord) -> TaskPayload? {
        guard isTaskRecordType(record.recordType) else { return nil }
        let id = UUID(uuidString: record.recordID.recordName)
        guard let id else { return nil }

        let intervalValue = intValue(in: record, keys: ["interval", "INTERVAL", "zinterval", "ZINTERVAL", "cd_interval"])
        let nameValue = stringValue(in: record, keys: ["name", "NAME", "zname", "ZNAME", "cd_name"])
        let emojiValue = stringValue(in: record, keys: ["emoji", "EMOJI", "zemoji", "ZEMOJI", "cd_emoji"])
        let placeIDValue = uuidValue(in: record, keys: ["placeID", "placeId", "PLACEID", "zplaceid", "ZPLACEID", "cd_placeid"])
        let tagsStorageValue = stringValue(in: record, keys: ["tagsStorage", "tagsstorage", "TAGSSTORAGE", "ztagsstorage", "ZTAGSSTORAGE", "cd_tagsstorage"])
        let stepsStorageValue = stringValue(in: record, keys: ["stepsStorage", "stepsstorage", "STEPSSTORAGE", "zstepsstorage", "ZSTEPSSTORAGE", "cd_stepsstorage"])
        let checklistItemsStorageValue = stringValue(
            in: record,
            keys: [
                "checklistItemsStorage",
                "checklistitemsstorage",
                "CHECKLISTITEMSSTORAGE",
                "zchecklistitemsstorage",
                "ZCHECKLISTITEMSSTORAGE",
                "cd_checklistitemsstorage"
            ]
        )
        let scheduleModeValue = stringValue(
            in: record,
            keys: [
                "scheduleModeRawValue",
                "schedulemoderawvalue",
                "SCHEDULEMODERAWVALUE",
                "zschedulemoderawvalue",
                "ZSCHEDULEMODERAWVALUE",
                "cd_schedulemoderawvalue"
            ]
        )
        let lastDoneValue = dateValue(in: record, keys: ["lastDone", "LASTDONE", "zlastdone", "ZLASTDONE", "cd_lastdone"])
        let scheduleAnchorValue = dateValue(
            in: record,
            keys: ["scheduleAnchor", "SCHEDULEANCHOR", "zscheduleanchor", "ZSCHEDULEANCHOR", "cd_scheduleanchor"]
        )
        let pausedAtValue = dateValue(
            in: record,
            keys: ["pausedAt", "PAUSEDAT", "zpausedat", "ZPAUSEDAT", "cd_pausedat"]
        )
        let pinnedAtValue = dateValue(
            in: record,
            keys: ["pinnedAt", "PINNEDAT", "zpinnedat", "ZPINNEDAT", "cd_pinnedat"]
        )
        let completedStepCountValue = intValue(
            in: record,
            keys: ["completedStepCount", "COMPLETEDSTEPCOUNT", "zcompletedstepcount", "ZCOMPLETEDSTEPCOUNT", "cd_completedstepcount"]
        )
        let sequenceStartedAtValue = dateValue(
            in: record,
            keys: ["sequenceStartedAt", "SEQUENCESTARTEDAT", "zsequencestartedat", "ZSEQUENCESTARTEDAT", "cd_sequencestartedat"]
        )

        guard
            intervalValue != nil
                || nameValue != nil
                || emojiValue != nil
                || placeIDValue != nil
                || tagsStorageValue != nil
                || stepsStorageValue != nil
                || checklistItemsStorageValue != nil
                || scheduleModeValue != nil
                || lastDoneValue != nil
                || scheduleAnchorValue != nil
                || pausedAtValue != nil
                || pinnedAtValue != nil
                || completedStepCountValue != nil
                || sequenceStartedAtValue != nil
        else {
            return nil
        }

        let stepsValue: [RoutineStep]?
        if let stepsStorageValue {
            let data = Data(stepsStorageValue.utf8)
            stepsValue = (try? JSONDecoder().decode([RoutineStep].self, from: data)).map(RoutineStep.sanitized)
        } else {
            stepsValue = nil
        }

        let checklistItemsValue: [RoutineChecklistItem]?
        if let checklistItemsStorageValue {
            let data = Data(checklistItemsStorageValue.utf8)
            checklistItemsValue = (try? JSONDecoder().decode([RoutineChecklistItem].self, from: data)).map(RoutineChecklistItem.sanitized)
        } else {
            checklistItemsValue = nil
        }

        return TaskPayload(
            id: id,
            name: nameValue,
            emoji: emojiValue,
            placeID: placeIDValue,
            tags: tagsStorageValue.map(RoutineTag.deserialize),
            steps: stepsValue,
            checklistItems: checklistItemsValue,
            scheduleMode: scheduleModeValue.flatMap(RoutineScheduleMode.init(rawValue:)),
            interval: Int16(clamping: intervalValue ?? 1),
            lastDone: lastDoneValue,
            scheduleAnchor: scheduleAnchorValue,
            pausedAt: pausedAtValue,
            pinnedAt: pinnedAtValue,
            completedStepCount: Int16(clamping: completedStepCountValue ?? 0),
            sequenceStartedAt: sequenceStartedAtValue
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
    private static func upsertPlace(_ payload: PlacePayload, in context: ModelContext) throws {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == payloadID
            }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.name = RoutinePlace.cleanedName(payload.name) ?? existing.displayName
            existing.latitude = payload.latitude
            existing.longitude = payload.longitude
            existing.radiusMeters = max(payload.radiusMeters, 25)
            if let createdAt = payload.createdAt {
                existing.createdAt = createdAt
            }
            return
        }

        context.insert(
            RoutinePlace(
                id: payload.id,
                name: RoutinePlace.cleanedName(payload.name) ?? "Place",
                latitude: payload.latitude,
                longitude: payload.longitude,
                radiusMeters: payload.radiusMeters,
                createdAt: payload.createdAt ?? Date()
            )
        )
    }

    @MainActor
    private static func upsertTask(_ payload: TaskPayload, in context: ModelContext) throws -> UUID {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == payloadID
            }
        )
        let normalizedIncomingName = RoutineTask.normalizedName(payload.name)

        if let existing = try context.fetch(descriptor).first {
            if let normalizedIncomingName,
               let taskWithSameName = try task(matchingNormalizedName: normalizedIncomingName, in: context),
               taskWithSameName.id != existing.id {
                // Keep local uniqueness invariant if cloud data contains a duplicate name.
                taskWithSameName.name = RoutineTask.trimmedName(payload.name)
                taskWithSameName.emoji = payload.emoji
                taskWithSameName.placeID = payload.placeID
                if let tags = payload.tags {
                    taskWithSameName.tags = tags
                }
                if let steps = payload.steps {
                    taskWithSameName.replaceSteps(steps)
                }
                if let checklistItems = payload.checklistItems {
                    taskWithSameName.replaceChecklistItems(checklistItems)
                }
                if let scheduleMode = payload.scheduleMode {
                    taskWithSameName.scheduleMode = scheduleMode
                }
                taskWithSameName.interval = payload.interval
                taskWithSameName.lastDone = payload.lastDone
                taskWithSameName.scheduleAnchor = payload.scheduleAnchor ?? payload.lastDone ?? taskWithSameName.scheduleAnchor
                taskWithSameName.pausedAt = payload.pausedAt
                taskWithSameName.pinnedAt = payload.pinnedAt
                taskWithSameName.completedStepCount = payload.completedStepCount
                taskWithSameName.sequenceStartedAt = payload.sequenceStartedAt
                try migrateLogs(from: existing.id, to: taskWithSameName.id, in: context)
                return taskWithSameName.id
            }

            existing.name = RoutineTask.trimmedName(payload.name)
            existing.emoji = payload.emoji
            existing.placeID = payload.placeID
            if let tags = payload.tags {
                existing.tags = tags
            }
            if let steps = payload.steps {
                existing.replaceSteps(steps)
            }
            if let checklistItems = payload.checklistItems {
                existing.replaceChecklistItems(checklistItems)
            }
            if let scheduleMode = payload.scheduleMode {
                existing.scheduleMode = scheduleMode
            }
            existing.interval = payload.interval
            existing.lastDone = payload.lastDone
            existing.scheduleAnchor = payload.scheduleAnchor ?? payload.lastDone ?? existing.scheduleAnchor
            existing.pausedAt = payload.pausedAt
            existing.pinnedAt = payload.pinnedAt
            existing.completedStepCount = payload.completedStepCount
            existing.sequenceStartedAt = payload.sequenceStartedAt
            return existing.id
        } else {
            if let normalizedIncomingName,
               let taskWithSameName = try task(matchingNormalizedName: normalizedIncomingName, in: context) {
                taskWithSameName.emoji = payload.emoji
                taskWithSameName.placeID = payload.placeID
                if let tags = payload.tags {
                    taskWithSameName.tags = tags
                }
                if let steps = payload.steps {
                    taskWithSameName.replaceSteps(steps)
                }
                if let checklistItems = payload.checklistItems {
                    taskWithSameName.replaceChecklistItems(checklistItems)
                }
                if let scheduleMode = payload.scheduleMode {
                    taskWithSameName.scheduleMode = scheduleMode
                }
                taskWithSameName.interval = payload.interval
                taskWithSameName.lastDone = payload.lastDone
                taskWithSameName.scheduleAnchor = payload.scheduleAnchor ?? payload.lastDone ?? taskWithSameName.scheduleAnchor
                taskWithSameName.pausedAt = payload.pausedAt
                taskWithSameName.pinnedAt = payload.pinnedAt
                taskWithSameName.completedStepCount = payload.completedStepCount
                taskWithSameName.sequenceStartedAt = payload.sequenceStartedAt
                try migrateLogs(from: payload.id, to: taskWithSameName.id, in: context)
                return taskWithSameName.id
            }

            context.insert(
                RoutineTask(
                    id: payload.id,
                    name: RoutineTask.trimmedName(payload.name),
                    emoji: payload.emoji,
                    placeID: payload.placeID,
                    tags: payload.tags ?? [],
                    steps: payload.steps ?? [],
                    checklistItems: payload.checklistItems ?? [],
                    scheduleMode: payload.scheduleMode,
                    interval: payload.interval,
                    lastDone: payload.lastDone,
                    scheduleAnchor: payload.scheduleAnchor,
                    pausedAt: payload.pausedAt,
                    pinnedAt: payload.pinnedAt,
                    completedStepCount: payload.completedStepCount,
                    sequenceStartedAt: payload.sequenceStartedAt
                )
            )
            return payload.id
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
        } else if let existing = try existingLog(matching: payload, in: context) {
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

    @MainActor
    private static func existingLog(
        matching payload: LogPayload,
        in context: ModelContext
    ) throws -> RoutineLog? {
        let taskID = payload.taskID
        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )

        return try context.fetch(descriptor).first { log in
            timestampsMatch(log.timestamp, payload.timestamp)
        }
    }

    @MainActor
    private static func deduplicateLogs(in context: ModelContext) throws {
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        var keptLogIDsByKey: [LogDeduplicationKey: UUID] = [:]
        for log in logs {
            let key = LogDeduplicationKey(taskID: log.taskID, timestamp: log.timestamp)
            if let keptLogID = keptLogIDsByKey[key], keptLogID != log.id {
                context.delete(log)
            } else {
                keptLogIDsByKey[key] = log.id
            }
        }
    }

    @MainActor
    private static func migrateLogs(
        from sourceTaskID: UUID,
        to targetTaskID: UUID,
        in context: ModelContext
    ) throws {
        guard sourceTaskID != targetTaskID else { return }

        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == sourceTaskID
            }
        )

        for log in try context.fetch(descriptor) {
            log.taskID = targetTaskID
        }
    }

    @MainActor
    private static func canonicalTaskID(for taskID: UUID, in context: ModelContext) -> UUID {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
        let task = try? context.fetch(descriptor).first
        return task?.id ?? taskID
    }

    private struct LogDeduplicationKey: Hashable {
        let taskID: UUID
        let timestampBucket: Int?

        init(taskID: UUID, timestamp: Date?) {
            self.taskID = taskID
            self.timestampBucket = timestamp.map { Int($0.timeIntervalSince1970.rounded()) }
        }
    }

    private static func timestampsMatch(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return abs(lhs.timeIntervalSince1970 - rhs.timeIntervalSince1970) < 1
        default:
            return false
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

    private static func doubleValue(in record: CKRecord, keys: [String]) -> Double? {
        for key in keys {
            if let value = record[key] as? NSNumber {
                return value.doubleValue
            }
            if let value = record[key] as? Double {
                return value
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()],
               let number = record[matchedKey] as? NSNumber {
                return number.doubleValue
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

    private static func isPlaceRecordType(_ recordType: String) -> Bool {
        let normalized = recordType.lowercased()
        return normalized.contains("routineplace")
            || normalized.contains("routine_place")
    }

    private static func isLogRecordType(_ recordType: String) -> Bool {
        let normalized = recordType.lowercased()
        return normalized.contains("routinelog")
            || normalized.contains("routine_log")
    }

    @MainActor
    private static func clearPlaceReference(placeID: UUID, in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.placeID == placeID {
            task.placeID = nil
        }
    }

    @MainActor
    private static func task(
        matchingNormalizedName normalizedName: String,
        in context: ModelContext
    ) throws -> RoutineTask? {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.first { task in
            RoutineTask.normalizedName(task.name) == normalizedName
        }
    }
}
