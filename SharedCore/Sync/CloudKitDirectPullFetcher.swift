import CloudKit
import Foundation

enum CloudKitDirectPullFetcher {
    static let manualRefreshTimeoutPolicy = CloudKitManualRefreshTimeoutPolicy(
        idleTimeoutSeconds: 60,
        hardLimitSeconds: 180
    )

    private static let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: "__defaultOwner__"
    )

    static func fetchZoneChanges(
        containerIdentifier: String
    ) async throws -> CloudKitDirectPullService.PullResult {
        let previousServerChangeToken = CloudKitDirectPullTokenStore.load(
            containerIdentifier: containerIdentifier
        )

        do {
            return try await fetchZoneChanges(
                containerIdentifier: containerIdentifier,
                previousServerChangeToken: previousServerChangeToken
            )
        } catch {
            guard previousServerChangeToken != nil,
                  isChangeTokenExpired(error) else {
                throw error
            }

            CloudKitDirectPullTokenStore.clear(containerIdentifier: containerIdentifier)
            return try await fetchZoneChanges(
                containerIdentifier: containerIdentifier,
                previousServerChangeToken: nil
            )
        }
    }

    private static func fetchZoneChanges(
        containerIdentifier: String,
        previousServerChangeToken: CKServerChangeToken?
    ) async throws -> CloudKitDirectPullService.PullResult {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let mode: CloudSyncManualRefreshProgress.Mode = previousServerChangeToken == nil
            ? .full
            : .incremental
        let requestState = CloudKitZoneChangesRequestState(
            previousServerChangeToken: previousServerChangeToken,
            mode: mode,
            timeoutPolicy: manualRefreshTimeoutPolicy
        )
        CloudKitSyncDiagnostics.recordManualRefreshStarted(mode: mode)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                config.previousServerChangeToken = previousServerChangeToken
                config.desiredKeys = nil

                let operation = CKFetchRecordZoneChangesOperation(
                    recordZoneIDs: [zoneID],
                    configurationsByRecordZoneID: [zoneID: config]
                )
                configureManualRefreshOperation(operation)
                operation.fetchAllChanges = true

                operation.recordWasChangedBlock = { _, result in
                    switch result {
                    case let .success(record):
                        requestState.recordChanged(record)
                    case let .failure(error):
                        requestState.recordFailure(error)
                    }
                }

                operation.recordWithIDWasDeletedBlock = { recordID, _ in
                    requestState.recordDeleted(recordID)
                }

                operation.recordZoneFetchResultBlock = { _, result in
                    switch result {
                    case let .success(zoneResult):
                        requestState.recordZoneProgress(
                            serverChangeToken: zoneResult.serverChangeToken
                        )
                    case let .failure(error):
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

                guard requestState.startWatchdogs() else {
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
        configuration.timeoutIntervalForRequest = manualRefreshTimeoutPolicy.idleTimeoutSeconds
        configuration.timeoutIntervalForResource = manualRefreshTimeoutPolicy.hardLimitSeconds
        operation.configuration = configuration
    }

    private static func isChangeTokenExpired(_ error: Error) -> Bool {
        guard let cloudError = error as? CKError else { return false }
        if cloudError.code == .changeTokenExpired {
            return true
        }
        guard cloudError.code == .partialFailure,
              let partialErrors = cloudError.partialErrorsByItemID else {
            return false
        }
        return partialErrors.values.contains(where: isChangeTokenExpired)
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

struct CloudKitManualRefreshTimeoutPolicy: Equatable, Sendable {
    var idleTimeoutSeconds: TimeInterval
    var hardLimitSeconds: TimeInterval
}

enum CloudKitDirectPullTokenStore {
    private static let keyPrefix = "cloudKitDirectPull.serverChangeToken."

    static func load(
        containerIdentifier: String,
        defaults: UserDefaults = .standard
    ) -> CKServerChangeToken? {
        let key = storageKey(containerIdentifier: containerIdentifier)
        guard let data = defaults.data(forKey: key) else { return nil }

        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: data
            )
        } catch {
            defaults.removeObject(forKey: key)
            return nil
        }
    }

    static func save(
        _ token: CKServerChangeToken,
        containerIdentifier: String,
        defaults: UserDefaults = .standard
    ) {
        let key = storageKey(containerIdentifier: containerIdentifier)
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
            )
            defaults.set(data, forKey: key)
        } catch {
            defaults.removeObject(forKey: key)
        }
    }

    static func clear(
        containerIdentifier: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: storageKey(containerIdentifier: containerIdentifier))
    }

    static func clearAll(defaults: UserDefaults = .standard) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    static func storageKey(containerIdentifier: String) -> String {
        keyPrefix + containerIdentifier
    }
}

private final class CloudKitZoneChangesRequestState: @unchecked Sendable {
    typealias PullResult = CloudKitDirectPullService.PullResult

    private let lock = NSLock()
    private var changedRecords: [CKRecord] = []
    private var deletedRecordIDs: [CKRecord.ID] = []
    private var serverChangeToken: CKServerChangeToken?
    private var continuation: CheckedContinuation<PullResult, Error>?
    private var operation: CKOperation?
    private var idleTimeoutTask: Task<Void, Never>?
    private var hardLimitTask: Task<Void, Never>?
    private var pendingResult: Result<PullResult, Error>?
    private var firstRecordError: Error?
    private var isFinished = false
    private var activityGeneration: UInt = 0
    private var lastReportedRecordCount = 0
    private let mode: CloudSyncManualRefreshProgress.Mode
    private let timeoutPolicy: CloudKitManualRefreshTimeoutPolicy

    init(
        previousServerChangeToken: CKServerChangeToken?,
        mode: CloudSyncManualRefreshProgress.Mode,
        timeoutPolicy: CloudKitManualRefreshTimeoutPolicy
    ) {
        self.serverChangeToken = previousServerChangeToken
        self.mode = mode
        self.timeoutPolicy = timeoutPolicy
    }

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

    func startWatchdogs() -> Bool {
        let oldIdleTimeoutTask: Task<Void, Never>?

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return false
        }
        oldIdleTimeoutTask = resetIdleTimeoutLocked()
        hardLimitTask = Task { [weak self, timeoutPolicy] in
            do {
                try await Task.sleep(for: .seconds(timeoutPolicy.hardLimitSeconds))
            } catch {
                return
            }
            self?.finishForHardLimit()
        }
        lock.unlock()

        oldIdleTimeoutTask?.cancel()
        return true
    }

    func recordChanged(_ record: CKRecord) {
        let progress: CloudSyncManualRefreshProgress?
        let oldIdleTimeoutTask: Task<Void, Never>?

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        changedRecords.append(record)
        oldIdleTimeoutTask = resetIdleTimeoutLocked()
        progress = progressToReportLocked()
        lock.unlock()

        oldIdleTimeoutTask?.cancel()
        if let progress {
            CloudKitSyncDiagnostics.recordManualRefreshProgress(progress)
        }
    }

    func recordDeleted(_ recordID: CKRecord.ID) {
        let progress: CloudSyncManualRefreshProgress?
        let oldIdleTimeoutTask: Task<Void, Never>?

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        deletedRecordIDs.append(recordID)
        oldIdleTimeoutTask = resetIdleTimeoutLocked()
        progress = progressToReportLocked()
        lock.unlock()

        oldIdleTimeoutTask?.cancel()
        if let progress {
            CloudKitSyncDiagnostics.recordManualRefreshProgress(progress)
        }
    }

    func recordActivity() {
        let oldIdleTimeoutTask: Task<Void, Never>?

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        oldIdleTimeoutTask = resetIdleTimeoutLocked()
        lock.unlock()

        oldIdleTimeoutTask?.cancel()
    }

    func recordFailure(_ error: Error) {
        let oldIdleTimeoutTask: Task<Void, Never>?

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        if firstRecordError == nil {
            firstRecordError = error
        }
        oldIdleTimeoutTask = resetIdleTimeoutLocked()
        lock.unlock()

        oldIdleTimeoutTask?.cancel()
    }

    func recordZoneProgress(serverChangeToken: CKServerChangeToken?) {
        lock.lock()
        if !isFinished, let serverChangeToken {
            self.serverChangeToken = serverChangeToken
        }
        lock.unlock()
        recordActivity()
    }

    func finishSuccessfully() {
        finish { changedRecords, deletedRecordIDs, serverChangeToken in
            if let firstRecordError = self.firstRecordError {
                return .failure(firstRecordError)
            }
            return .success(
                PullResult(
                    changedRecords: changedRecords,
                    deletedRecordIDs: deletedRecordIDs,
                    serverChangeToken: serverChangeToken,
                    wasIncremental: self.mode == .incremental
                )
            )
        }
    }

    func finish(
        _ result: Result<PullResult, Error>,
        cancellingOperation: Bool = false
    ) {
        finish(
            result: { _, _, _ in result },
            cancellingOperation: cancellingOperation
        )
    }

    private func finishForInactivity(activityGeneration: UInt) {
        lock.lock()
        guard !isFinished, self.activityGeneration == activityGeneration else {
            lock.unlock()
            return
        }
        lock.unlock()

        finish(
            result: { changedRecords, deletedRecordIDs, _ in
                .failure(
                    CloudSyncManualRefreshError.stalled(
                        receivedRecordCount: changedRecords.count + deletedRecordIDs.count
                    )
                )
            },
            cancellingOperation: true
        )
    }

    private func finishForHardLimit() {
        finish(
            result: { changedRecords, deletedRecordIDs, _ in
                .failure(
                    CloudSyncManualRefreshError.hardLimitReached(
                        receivedRecordCount: changedRecords.count + deletedRecordIDs.count
                    )
                )
            },
            cancellingOperation: true
        )
    }

    private func finish(
        result makeResult: (
            [CKRecord],
            [CKRecord.ID],
            CKServerChangeToken?
        ) -> Result<PullResult, Error>,
        cancellingOperation: Bool = false
    ) {
        let continuation: CheckedContinuation<PullResult, Error>?
        let operation: CKOperation?
        let idleTimeoutTask: Task<Void, Never>?
        let hardLimitTask: Task<Void, Never>?
        let result: Result<PullResult, Error>
        let progress: CloudSyncManualRefreshProgress

        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        continuation = self.continuation
        operation = self.operation
        idleTimeoutTask = self.idleTimeoutTask
        hardLimitTask = self.hardLimitTask
        result = makeResult(changedRecords, deletedRecordIDs, serverChangeToken)
        progress = currentProgressLocked()
        if continuation == nil {
            pendingResult = result
        }
        lock.unlock()

        idleTimeoutTask?.cancel()
        hardLimitTask?.cancel()
        if cancellingOperation {
            operation?.cancel()
        }
        switch result {
        case .success:
            CloudKitSyncDiagnostics.recordManualRefreshDownloadFinished(progress)
        case let .failure(error):
            CloudKitSyncDiagnostics.recordManualRefreshFailure(error, progress: progress)
        }
        continuation?.resume(with: result)
    }

    private func resetIdleTimeoutLocked() -> Task<Void, Never>? {
        activityGeneration &+= 1
        let expectedGeneration = activityGeneration
        let oldTask = idleTimeoutTask
        idleTimeoutTask = Task { [weak self, timeoutPolicy] in
            do {
                try await Task.sleep(for: .seconds(timeoutPolicy.idleTimeoutSeconds))
            } catch {
                return
            }
            self?.finishForInactivity(activityGeneration: expectedGeneration)
        }
        return oldTask
    }

    private func progressToReportLocked() -> CloudSyncManualRefreshProgress? {
        let progress = currentProgressLocked()
        guard progress.receivedRecordCount == 1
                || progress.receivedRecordCount - lastReportedRecordCount >= 25 else {
            return nil
        }
        lastReportedRecordCount = progress.receivedRecordCount
        return progress
    }

    private func currentProgressLocked() -> CloudSyncManualRefreshProgress {
        CloudSyncManualRefreshProgress(
            mode: mode,
            changedRecordCount: changedRecords.count,
            deletedRecordCount: deletedRecordIDs.count
        )
    }
}
