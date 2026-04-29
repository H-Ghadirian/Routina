import CloudKit
import Foundation
import SwiftData

enum CloudSharingService {
    private static let recordType = "RoutinaSharedTask"
    private static let payloadKey = "payload"
    private static let updatedAtKey = "updatedAt"
    private static let zoneName = "RoutinaRoutineShares"
    private static let shareType = "ir.hamedgh.Routina.routine-task"

    private static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    struct SharedTaskPayload: Codable, Sendable {
        var id: UUID
        var name: String?
        var emoji: String?
        var notes: String?
        var link: String?
        var deadline: Date?
        var reminderAt: Date?
        var priority: RoutineTaskPriority
        var importance: RoutineTaskImportance
        var urgency: RoutineTaskUrgency
        var pressure: RoutineTaskPressure
        var pressureUpdatedAt: Date?
        var imageData: Data?
        var placeID: UUID?
        var tags: [String]
        var relationships: [RoutineTaskRelationship]
        var steps: [RoutineStep]
        var checklistItems: [RoutineChecklistItem]
        var scheduleMode: RoutineScheduleMode
        var interval: Int16
        var recurrenceRule: RoutineRecurrenceRule?
        var lastDone: Date?
        var canceledAt: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var snoozedUntil: Date?
        var pinnedAt: Date?
        var completedStepCount: Int16
        var sequenceStartedAt: Date?
        var color: RoutineTaskColor
        var createdAt: Date?
        var todoStateRawValue: String?
        var activityStateRawValue: String?
        var ongoingSince: Date?
        var autoAssumeDailyDone: Bool
        var estimatedDurationMinutes: Int?
        var storyPoints: Int?
        var focusModeEnabled: Bool
    }

    static func prepareShare(
        for task: RoutineTask,
        completion: @escaping @Sendable (CKShare?, CKContainer?, Error?) -> Void
    ) {
        guard let containerIdentifier = AppEnvironment.cloudKitContainerIdentifier else {
            completion(nil, nil, CloudSharingError.cloudSyncDisabled)
            return
        }

        let payload = SharedTaskPayload(task: task)
        Task {
            let container = CKContainer(identifier: containerIdentifier)
            do {
                let share = try await saveShare(payload: payload, in: container)
                completion(share, container, nil)
            } catch {
                completion(nil, container, error)
            }
        }
    }

    @MainActor
    static func acceptShare(metadata: CKShare.Metadata, into context: ModelContext) async throws {
        let container = CKContainer(identifier: metadata.containerIdentifier)
        let rootRecordID = metadata.hierarchicalRootRecordID

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.acceptSharesResultBlock = { result in
                continuation.resume(with: result.map { _ in () })
            }
            container.add(operation)
        }

        guard let rootRecordID else {
            throw CloudSharingError.missingRootRecord
        }

        let records = try await container.sharedCloudDatabase.records(for: [rootRecordID])
        guard case let .success(record)? = records[rootRecordID] else {
            throw CloudSharingError.missingRootRecord
        }

        try importSharedTask(from: record, into: context)
    }

    @MainActor
    static func importSharedTask(from record: CKRecord, into context: ModelContext) throws {
        guard record.recordType == recordType,
              let payloadString = record[payloadKey] as? String,
              let payloadData = payloadString.data(using: .utf8)
        else {
            throw CloudSharingError.invalidSharedRecord
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(SharedTaskPayload.self, from: payloadData)
        try upsert(payload: payload, in: context)
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
    }

    private static func saveShare(payload: SharedTaskPayload, in container: CKContainer) async throws -> CKShare {
        let database = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: payload.id.uuidString, zoneID: zoneID)
        try await ensureZoneExists(in: database)

        let record = await existingRecord(for: recordID, in: database)
            ?? CKRecord(recordType: recordType, recordID: recordID)
        try apply(payload: payload, to: record)

        if let shareReference = record.share,
           let existingShare = try? await fetchRecord(with: shareReference.recordID, in: database) as? CKShare {
            _ = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .changedKeys,
                atomically: true
            )
            return existingShare
        }

        let share = CKShare(rootRecord: record)
        share.publicPermission = .readOnly
        share[CKShare.SystemFieldKey.title] = payload.displayTitle as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = shareType as CKRecordValue

        let result = try await database.modifyRecords(
            saving: [record, share],
            deleting: [],
            savePolicy: .changedKeys,
            atomically: true
        )

        if case let .failure(error)? = result.saveResults[record.recordID] {
            throw error
        }
        if case let .failure(error)? = result.saveResults[share.recordID] {
            throw error
        }

        return share
    }

    private static func ensureZoneExists(in database: CKDatabase) async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        let result = try await database.modifyRecordZones(saving: [zone], deleting: [])
        if case let .failure(error)? = result.saveResults[zoneID],
           !isZoneAlreadyExistsError(error) {
            throw error
        }
    }

    private static func existingRecord(for recordID: CKRecord.ID, in database: CKDatabase) async -> CKRecord? {
        guard let result = try? await database.records(for: [recordID]) else { return nil }
        guard case let .success(record)? = result[recordID] else { return nil }
        return record
    }

    private static func fetchRecord(with recordID: CKRecord.ID, in database: CKDatabase) async throws -> CKRecord {
        let result = try await database.records(for: [recordID])
        guard case let .success(record)? = result[recordID] else {
            throw CloudSharingError.missingRootRecord
        }
        return record
    }

    private static func apply(payload: SharedTaskPayload, to record: CKRecord) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        guard let payloadString = String(data: data, encoding: .utf8) else {
            throw CloudSharingError.invalidPayload
        }
        record[payloadKey] = payloadString as CKRecordValue
        record[updatedAtKey] = Date() as CKRecordValue
    }

    @MainActor
    private static func upsert(payload: SharedTaskPayload, in context: ModelContext) throws {
        let id = payload.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == id
            }
        )

        if let existing = try context.fetch(descriptor).first {
            payload.apply(to: existing)
        } else {
            context.insert(RoutineTask(payload: payload))
        }
    }

    private static func isZoneAlreadyExistsError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        return ckError.code == .serverRecordChanged
    }
}

enum CloudSharingError: LocalizedError {
    case cloudSyncDisabled
    case invalidPayload
    case invalidSharedRecord
    case missingRootRecord

    var errorDescription: String? {
        switch self {
        case .cloudSyncDisabled:
            return "CloudKit sharing is unavailable because Cloud sync is disabled for this build."
        case .invalidPayload:
            return "The routine could not be prepared for sharing."
        case .invalidSharedRecord:
            return "The CloudKit share did not contain a Routina routine."
        case .missingRootRecord:
            return "The shared routine record could not be found."
        }
    }
}

extension CloudSharingService.SharedTaskPayload {
    init(task: RoutineTask) {
        self.id = task.id
        self.name = task.name
        self.emoji = task.emoji
        self.notes = task.notes
        self.link = task.link
        self.deadline = task.deadline
        self.reminderAt = task.reminderAt
        self.priority = task.priority
        self.importance = task.importance
        self.urgency = task.urgency
        self.pressure = task.pressure
        self.pressureUpdatedAt = task.pressureUpdatedAt
        self.imageData = task.imageData
        self.placeID = task.placeID
        self.tags = task.tags
        self.relationships = task.relationships
        self.steps = task.steps
        self.checklistItems = task.checklistItems
        self.scheduleMode = task.scheduleMode
        self.interval = task.interval
        self.recurrenceRule = task.recurrenceRule
        self.lastDone = task.lastDone
        self.canceledAt = task.canceledAt
        self.scheduleAnchor = task.scheduleAnchor
        self.pausedAt = task.pausedAt
        self.snoozedUntil = task.snoozedUntil
        self.pinnedAt = task.pinnedAt
        self.completedStepCount = task.completedStepCount
        self.sequenceStartedAt = task.sequenceStartedAt
        self.color = task.color
        self.createdAt = task.createdAt
        self.todoStateRawValue = task.todoStateRawValue
        self.activityStateRawValue = task.activityStateRawValue
        self.ongoingSince = task.ongoingSince
        self.autoAssumeDailyDone = task.autoAssumeDailyDone
        self.estimatedDurationMinutes = task.estimatedDurationMinutes
        self.storyPoints = task.storyPoints
        self.focusModeEnabled = task.focusModeEnabled
    }

    var displayTitle: String {
        let title = RoutineTask.trimmedName(name) ?? "Routina Task"
        if let emoji, !emoji.isEmpty {
            return "\(emoji) \(title)"
        }
        return title
    }

    @MainActor
    func apply(to task: RoutineTask) {
        task.name = RoutineTask.trimmedName(name)
        task.emoji = emoji
        task.notes = RoutineTask.sanitizedNotes(notes)
        task.link = RoutineTask.sanitizedLink(link)
        task.deadline = scheduleMode == .oneOff ? deadline : nil
        task.reminderAt = reminderAt
        task.priority = priority
        task.importance = importance
        task.urgency = urgency
        task.pressure = pressure
        task.pressureUpdatedAt = pressure == .none ? nil : pressureUpdatedAt
        task.imageData = imageData
        task.placeID = placeID
        task.tags = tags
        task.replaceRelationships(relationships)
        task.replaceSteps(steps)
        task.replaceChecklistItems(scheduleMode == .oneOff ? [] : checklistItems)
        task.scheduleMode = scheduleMode
        task.recurrenceRule = recurrenceRule ?? .interval(days: max(Int(interval), 1))
        task.interval = Int16(clamping: max(Int(interval), 1))
        task.lastDone = lastDone
        task.canceledAt = scheduleMode == .oneOff ? canceledAt : nil
        task.scheduleAnchor = scheduleMode == .oneOff ? lastDone : (scheduleAnchor ?? lastDone)
        task.pausedAt = pausedAt
        task.snoozedUntil = snoozedUntil
        task.pinnedAt = pinnedAt
        task.completedStepCount = completedStepCount
        task.sequenceStartedAt = sequenceStartedAt
        task.color = color
        task.createdAt = createdAt
        task.todoStateRawValue = todoStateRawValue
        task.activityStateRawValue = RoutineActivityState(rawValue: activityStateRawValue ?? "")?.rawValue ?? RoutineActivityState.idle.rawValue
        task.ongoingSince = ongoingSince
        task.autoAssumeDailyDone = autoAssumeDailyDone
        task.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
        task.storyPoints = RoutineTask.sanitizedStoryPoints(storyPoints)
        task.focusModeEnabled = focusModeEnabled
    }
}

private extension RoutineTask {
    convenience init(payload: CloudSharingService.SharedTaskPayload) {
        self.init(
            id: payload.id,
            name: RoutineTask.trimmedName(payload.name),
            emoji: payload.emoji,
            notes: payload.notes,
            link: payload.link,
            deadline: payload.deadline,
            reminderAt: payload.reminderAt,
            priority: payload.priority,
            importance: payload.importance,
            urgency: payload.urgency,
            pressure: payload.pressure,
            pressureUpdatedAt: payload.pressureUpdatedAt,
            imageData: payload.imageData,
            placeID: payload.placeID,
            tags: payload.tags,
            relationships: payload.relationships,
            steps: payload.steps,
            checklistItems: payload.scheduleMode == .oneOff ? [] : payload.checklistItems,
            scheduleMode: payload.scheduleMode,
            interval: payload.interval,
            recurrenceRule: payload.recurrenceRule,
            lastDone: payload.lastDone,
            canceledAt: payload.canceledAt,
            scheduleAnchor: payload.scheduleAnchor,
            pausedAt: payload.pausedAt,
            snoozedUntil: payload.snoozedUntil,
            pinnedAt: payload.pinnedAt,
            completedStepCount: payload.completedStepCount,
            sequenceStartedAt: payload.sequenceStartedAt,
            color: payload.color,
            createdAt: payload.createdAt,
            todoStateRawValue: payload.todoStateRawValue,
            activityStateRawValue: payload.activityStateRawValue,
            ongoingSince: payload.ongoingSince,
            autoAssumeDailyDone: payload.autoAssumeDailyDone,
            estimatedDurationMinutes: payload.estimatedDurationMinutes,
            storyPoints: payload.storyPoints,
            focusModeEnabled: payload.focusModeEnabled
        )
    }
}
