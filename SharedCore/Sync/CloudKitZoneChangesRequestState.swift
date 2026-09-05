import CloudKit
import Foundation

final class CloudKitZoneChangesRequestState: @unchecked Sendable {
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
        guard
            progress.receivedRecordCount == 1
                || progress.receivedRecordCount - lastReportedRecordCount >= 25
        else {
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
