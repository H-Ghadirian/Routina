import CloudKit
import Foundation

enum CloudKitDirectPullFetcher {
    private static let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: "__defaultOwner__"
    )

    static func fetchZoneChanges(
        containerIdentifier: String
    ) async throws -> CloudKitDirectPullService.PullResult {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            func resumeIfNeeded(_ result: Result<CloudKitDirectPullService.PullResult, Error>) {
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
                            CloudKitDirectPullService.PullResult(
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

    /// Foreground reconciliation needs to discover a remote active Focus timer,
    /// not replay the entire private SwiftData zone. The full-zone fetch starts
    /// from a nil token and is reserved for explicit, user-initiated sync.
    static func fetchActiveFocusRecords(
        containerIdentifier: String,
        knownActiveFocusIDs: [UUID]
    ) async throws -> [CKRecord] {
        // SwiftData mirrors managed objects as CD_<Entity> records and prefixes
        // persisted fields with CD_. Query the two active-state fields in the
        // CloudKit predicate so completed history is never replayed on launch.
        let activeFocusRecords = try await fetchRecords(
            recordType: "CD_FocusSession",
            predicate: NSPredicate(format: "CD_completedAt == nil AND CD_abandonedAt == nil"),
            containerIdentifier: containerIdentifier
        )

        // Sprint Focus is optional on older stores. A missing record type must
        // not suppress ordinary Focus discovery.
        let activeSprintFocusRecords = (try? await fetchRecords(
            recordType: "CD_SprintFocusSessionRecord",
            predicate: NSPredicate(format: "CD_stoppedAt == nil"),
            containerIdentifier: containerIdentifier
        )) ?? []

        // An already-active local timer also needs its current remote row. That
        // row may now be terminal, so it cannot be found by the active-only
        // queries above. Fetching these exact record IDs preserves the remote
        // stop path without replaying history.
        let currentLocalFocusRecords = try await fetchRecords(
            withIDs: knownActiveFocusIDs,
            containerIdentifier: containerIdentifier
        )

        return Dictionary(
            (activeFocusRecords + activeSprintFocusRecords + currentLocalFocusRecords)
                .map { ($0.recordID.recordName, $0) },
            uniquingKeysWith: { _, latest in latest }
        ).values.map { $0 }
    }

    private static func fetchRecords(
        withIDs recordIDs: [UUID],
        containerIdentifier: String
    ) async throws -> [CKRecord] {
        guard !recordIDs.isEmpty else { return [] }

        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let cloudRecordIDs = recordIDs.map {
            CKRecord.ID(recordName: $0.uuidString, zoneID: zoneID)
        }

        return try await withCheckedThrowingContinuation { continuation in
            var records: [CKRecord] = []
            var didResume = false
            func resumeIfNeeded(_ result: Result<[CKRecord], Error>) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let operation = CKFetchRecordsOperation(recordIDs: cloudRecordIDs)
            operation.perRecordResultBlock = { _, result in
                if case let .success(record) = result {
                    records.append(record)
                }
            }
            operation.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    resumeIfNeeded(.success(records))
                case let .failure(error):
                    resumeIfNeeded(.failure(error))
                }
            }
            database.add(operation)
        }
    }

    private static func fetchRecords(
        recordType: String,
        predicate: NSPredicate,
        containerIdentifier: String
    ) async throws -> [CKRecord] {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page = try await fetchRecordPage(
                recordType: recordType,
                predicate: predicate,
                cursor: cursor,
                database: database
            )
            records.append(contentsOf: page.records)
            cursor = page.cursor
        } while cursor != nil

        return records
    }

    private static func fetchRecordPage(
        recordType: String,
        predicate: NSPredicate,
        cursor: CKQueryOperation.Cursor?,
        database: CKDatabase
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            var records: [CKRecord] = []
            var didResume = false
            func resumeIfNeeded(
                _ result: Result<(records: [CKRecord], cursor: CKQueryOperation.Cursor?), Error>
            ) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(
                    query: CKQuery(recordType: recordType, predicate: predicate)
                )
                operation.zoneID = zoneID
            }

            operation.recordMatchedBlock = { _, result in
                switch result {
                case let .success(record):
                    records.append(record)
                case .failure:
                    // A malformed row should not block active timer discovery.
                    break
                }
            }

            operation.queryResultBlock = { result in
                switch result {
                case let .success(nextCursor):
                    resumeIfNeeded(.success((records, nextCursor)))
                case let .failure(error):
                    resumeIfNeeded(.failure(error))
                }
            }

            database.add(operation)
        }
    }
}
