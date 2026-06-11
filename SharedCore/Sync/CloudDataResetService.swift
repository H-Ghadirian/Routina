import CloudKit
import Foundation
import SwiftData
import UserNotifications

struct CloudDataResetRemoteStoreClient: Sendable {
    var deleteAllRecords: @Sendable (_ containerIdentifier: String) async throws -> Void

    static let live = CloudDataResetRemoteStoreClient { containerIdentifier in
        try await CloudKitUserDataDeletion.deleteAllRecords(
            containerIdentifier: containerIdentifier
        )
    }

    static let noop = CloudDataResetRemoteStoreClient { _ in }
}

enum CloudDataResetService {
    @MainActor
    static func resetAllUserData(
        cloudKitContainerIdentifier: String,
        modelContext: ModelContext,
        remoteStore: CloudDataResetRemoteStoreClient = .live
    ) async throws {
        try LocalUserDataResetService.wipeAllUserData(in: modelContext)
        clearLocalNotifications()
        try await remoteStore.deleteAllRecords(cloudKitContainerIdentifier)
    }

    private static func clearLocalNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}

enum LocalUserDataResetService {
    @MainActor
    static func wipeAllUserData(in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks {
            context.delete(task)
        }

        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        for goal in goals {
            context.delete(goal)
        }

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        for log in logs {
            context.delete(log)
        }

        let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
        for session in focusSessions {
            context.delete(session)
        }

        let sprintFocusSessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        for session in sprintFocusSessions {
            context.delete(session)
        }

        let sprintFocusAllocations = try context.fetch(FetchDescriptor<SprintFocusAllocationRecord>())
        for allocation in sprintFocusAllocations {
            context.delete(allocation)
        }

        let sleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
        for session in sleepSessions {
            context.delete(session)
        }

        let awaySessions = try context.fetch(FetchDescriptor<AwaySession>())
        for session in awaySessions {
            context.delete(session)
        }

        let placeCheckIns = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        for session in placeCheckIns {
            context.delete(session)
        }

        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        for place in places {
            context.delete(place)
        }

        let emotionLogs = try context.fetch(FetchDescriptor<EmotionLog>())
        for emotion in emotionLogs {
            context.delete(emotion)
        }

        let notes = try context.fetch(FetchDescriptor<RoutineNote>())
        for note in notes {
            context.delete(note)
        }

        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        for event in events {
            context.delete(event)
        }

        let noteAttachments = try context.fetch(FetchDescriptor<RoutineNoteAttachment>())
        for attachment in noteAttachments {
            context.delete(attachment)
        }

        let attachments = try context.fetch(FetchDescriptor<RoutineAttachment>())
        for att in attachments {
            context.delete(att)
        }

        let deviceActionLogs = try context.fetch(FetchDescriptor<RoutinaDeviceActionLog>())
        for log in deviceActionLogs {
            context.delete(log)
        }

        let deviceSessions = try context.fetch(FetchDescriptor<RoutinaDeviceSession>())
        for session in deviceSessions {
            context.delete(session)
        }

        let userPreferences = try context.fetch(FetchDescriptor<RoutinaUserPreferences>())
        for preferences in userPreferences {
            context.delete(preferences)
        }

        let dayPlanBlocks = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
        for block in dayPlanBlocks {
            context.delete(block)
        }

        let boardSprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        for sprint in boardSprints {
            context.delete(sprint)
        }

        let sprintAssignments = try context.fetch(FetchDescriptor<SprintAssignmentRecord>())
        for assignment in sprintAssignments {
            context.delete(assignment)
        }

        let boardBacklogs = try context.fetch(FetchDescriptor<BoardBacklogRecord>())
        for backlog in boardBacklogs {
            context.delete(backlog)
        }

        let backlogAssignments = try context.fetch(FetchDescriptor<BacklogAssignmentRecord>())
        for assignment in backlogAssignments {
            context.delete(assignment)
        }

        try context.save()
    }
}

private enum CloudKitUserDataDeletion {
    private static let swiftDataZoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: CKCurrentUserDefaultName
    )
    private static let sharedRoutineZoneID = CKRecordZone.ID(
        zoneName: "RoutinaRoutineShares",
        ownerName: CKCurrentUserDefaultName
    )
    private static let userOwnedZoneIDs = [
        swiftDataZoneID,
        sharedRoutineZoneID,
    ]
    private static let deletionBatchSize = 350

    static func deleteAllRecords(containerIdentifier: String) async throws {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        for zoneID in userOwnedZoneIDs {
            let recordIDs = try await fetchAllRecordIDs(in: database, zoneID: zoneID)
            guard !recordIDs.isEmpty else { continue }

            for batch in recordIDs.chunked(maxCount: deletionBatchSize) {
                try await delete(batch, in: database)
            }
        }
    }

    private static func fetchAllRecordIDs(
        in database: CKDatabase,
        zoneID: CKRecordZone.ID
    ) async throws -> [CKRecord.ID] {
        var allRecordIDs: [CKRecord.ID] = []
        var previousServerChangeToken: CKServerChangeToken?

        repeat {
            let page = try await fetchRecordIDPage(
                in: database,
                zoneID: zoneID,
                previousServerChangeToken: previousServerChangeToken
            )
            allRecordIDs.append(contentsOf: page.recordIDs)
            previousServerChangeToken = page.moreComing ? page.serverChangeToken : nil
            if !page.moreComing {
                break
            }
        } while previousServerChangeToken != nil

        return allRecordIDs
    }

    private static func fetchRecordIDPage(
        in database: CKDatabase,
        zoneID: CKRecordZone.ID,
        previousServerChangeToken: CKServerChangeToken?
    ) async throws -> (recordIDs: [CKRecord.ID], serverChangeToken: CKServerChangeToken?, moreComing: Bool) {
        try await withCheckedThrowingContinuation { continuation in
            var recordIDs: [CKRecord.ID] = []
            var serverChangeToken: CKServerChangeToken?
            var moreComing = false
            var didResume = false

            func resumeIfNeeded(_ result: Result<(recordIDs: [CKRecord.ID], serverChangeToken: CKServerChangeToken?, moreComing: Bool), Error>) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = previousServerChangeToken
            configuration.desiredKeys = []

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: configuration]
            )

            operation.recordWasChangedBlock = { recordID, result in
                if case .success = result {
                    recordIDs.append(recordID)
                }
            }

            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case let .success(zoneResult):
                    serverChangeToken = zoneResult.serverChangeToken
                    moreComing = zoneResult.moreComing
                case let .failure(error):
                    if isMissingZoneError(error) {
                        resumeIfNeeded(
                            .success((recordIDs: [], serverChangeToken: nil, moreComing: false))
                        )
                    } else {
                        resumeIfNeeded(.failure(error))
                    }
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    resumeIfNeeded(
                        .success(
                            (
                                recordIDs: recordIDs,
                                serverChangeToken: serverChangeToken,
                                moreComing: moreComing
                            )
                        )
                    )
                case let .failure(error):
                    if isMissingZoneError(error) {
                        resumeIfNeeded(
                            .success((recordIDs: [], serverChangeToken: nil, moreComing: false))
                        )
                    } else {
                        resumeIfNeeded(.failure(error))
                    }
                }
            }

            database.add(operation)
        }
    }

    private static func delete(_ recordIDs: [CKRecord.ID], in database: CKDatabase) async throws {
        guard !recordIDs.isEmpty else { return }

        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(
                recordsToSave: nil,
                recordIDsToDelete: recordIDs
            )

            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    if isIgnorableDeleteError(error) {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }

            database.add(operation)
        }
    }

    private static func isMissingZoneError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        if ckError.code == .zoneNotFound {
            return true
        }

        if ckError.code == .partialFailure,
           let partialErrors = ckError.partialErrorsByItemID,
           !partialErrors.isEmpty {
            return partialErrors.values.allSatisfy(isMissingZoneError)
        }

        return false
    }

    private static func isIgnorableDeleteError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        if ckError.code == .unknownItem || ckError.code == .zoneNotFound {
            return true
        }

        if ckError.code == .partialFailure,
           let partialErrors = ckError.partialErrorsByItemID,
           !partialErrors.isEmpty {
            return partialErrors.values.allSatisfy(isIgnorableDeleteError)
        }

        return false
    }
}

private extension Array {
    func chunked(maxCount: Int) -> [[Element]] {
        guard maxCount > 0 else { return [self] }
        var chunks: [[Element]] = []
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: maxCount, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[start..<end]))
            start = end
        }
        return chunks
    }
}
