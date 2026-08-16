import CloudKit
import Foundation

enum CloudKitDirectPullFetcher {
    static let manualRefreshTimeoutSeconds: TimeInterval = 60

    private static let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: "__defaultOwner__"
    )

    static func fetchZoneChanges(
        containerIdentifier: String
    ) async throws -> CloudKitDirectPullService.PullResult {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let requestState = CloudKitZoneChangesRequestState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                config.previousServerChangeToken = nil
                config.desiredKeys = nil

                let operation = CKFetchRecordZoneChangesOperation(
                    recordZoneIDs: [zoneID],
                    configurationsByRecordZoneID: [zoneID: config]
                )
                configureManualRefreshOperation(operation)

                operation.recordWasChangedBlock = { _, result in
                    if case let .success(record) = result {
                        requestState.recordChanged(record)
                    }
                }

                operation.recordWithIDWasDeletedBlock = { recordID, _ in
                    requestState.recordDeleted(recordID)
                }

                operation.recordZoneFetchResultBlock = { _, result in
                    if case let .failure(error) = result {
                        requestState.finish(.failure(error))
                    }
                }

                operation.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        requestState.finishSuccessfully()
                    case let .failure(error):
                        requestState.finish(.failure(error))
                    }
                }

                guard requestState.install(
                    continuation: continuation,
                    operation: operation
                ) else {
                    return
                }

                let timeoutTask = Task {
                    do {
                        try await Task.sleep(for: .seconds(manualRefreshTimeoutSeconds))
                    } catch {
                        return
                    }
                    requestState.finish(
                        .failure(CloudSyncManualRefreshError.timedOut),
                        cancellingOperation: true
                    )
                }
                guard requestState.install(timeoutTask: timeoutTask) else {
                    return
                }

                database.add(operation)
            }
        } onCancel: {
            requestState.finish(.failure(CancellationError()), cancellingOperation: true)
        }
    }

    static func configureManualRefreshOperation(_ operation: CKOperation) {
        let configuration = CKOperation.Configuration()
        configuration.qualityOfService = .userInitiated
        configuration.timeoutIntervalForRequest = manualRefreshTimeoutSeconds
        configuration.timeoutIntervalForResource = manualRefreshTimeoutSeconds
        operation.configuration = configuration
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

private final class CloudKitZoneChangesRequestState: @unchecked Sendable {
    typealias PullResult = CloudKitDirectPullService.PullResult

    private let lock = NSLock()
    private var changedRecords: [CKRecord] = []
    private var deletedRecordIDs: [CKRecord.ID] = []
    private var continuation: CheckedContinuation<PullResult, Error>?
    private var operation: CKOperation?
    private var timeoutTask: Task<Void, Never>?
    private var pendingResult: Result<PullResult, Error>?
    private var isFinished = false

    func install(
        continuation: CheckedContinuation<PullResult, Error>,
        operation: CKOperation
    ) -> Bool {
        lock.lock()
        self.operation = operation
        if let pendingResult {
            lock.unlock()
            operation.cancel()
            continuation.resume(with: pendingResult)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func install(timeoutTask: Task<Void, Never>) -> Bool {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            timeoutTask.cancel()
            return false
        }
        self.timeoutTask = timeoutTask
        lock.unlock()
        return true
    }

    func recordChanged(_ record: CKRecord) {
        lock.lock()
        if !isFinished {
            changedRecords.append(record)
        }
        lock.unlock()
    }

    func recordDeleted(_ recordID: CKRecord.ID) {
        lock.lock()
        if !isFinished {
            deletedRecordIDs.append(recordID)
        }
        lock.unlock()
    }

    func finishSuccessfully() {
        finish { changedRecords, deletedRecordIDs in
            .success(
                PullResult(
                    changedRecords: changedRecords,
                    deletedRecordIDs: deletedRecordIDs
                )
            )
        }
    }

    func finish(
        _ result: Result<PullResult, Error>,
        cancellingOperation: Bool = false
    ) {
        finish(
            result: { _, _ in result },
            cancellingOperation: cancellingOperation
        )
    }

    private func finish(
        result makeResult: ([CKRecord], [CKRecord.ID]) -> Result<PullResult, Error>,
        cancellingOperation: Bool = false
    ) {
        let continuation: CheckedContinuation<PullResult, Error>?
        let operation: CKOperation?
        let timeoutTask: Task<Void, Never>?
        let result: Result<PullResult, Error>

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        continuation = self.continuation
        operation = self.operation
        timeoutTask = self.timeoutTask
        result = makeResult(changedRecords, deletedRecordIDs)
        if continuation == nil {
            pendingResult = result
        }
        lock.unlock()

        timeoutTask?.cancel()
        if cancellingOperation {
            operation?.cancel()
        }
        continuation?.resume(with: result)
    }
}
