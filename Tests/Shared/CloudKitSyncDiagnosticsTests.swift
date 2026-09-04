import CloudKit
import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct CloudKitSyncDiagnosticsTests {
    @Test
    func manualRefreshOperationUsesIdleAndHardSafetyLimits() {
        let operation = CKFetchRecordZoneChangesOperation()

        CloudKitDirectPullFetcher.configureManualRefreshOperation(operation)

        #expect(
            CloudKitDirectPullFetcher.manualRefreshTimeoutPolicy
                == CloudKitManualRefreshTimeoutPolicy(
                    idleTimeoutSeconds: 60,
                    hardLimitSeconds: 180
                )
        )
        #expect(operation.configuration?.qualityOfService == .userInitiated)
        #expect(operation.configuration?.timeoutIntervalForRequest == 60)
        #expect(operation.configuration?.timeoutIntervalForResource == 180)
    }

    @Test
    func manualRefreshFeedbackDistinguishesNoResponseFromSlowProgress() {
        #expect(
            CloudSyncFeedbackSupport.manualRefreshErrorMessage(
                for: CloudSyncManualRefreshError.stalled(receivedRecordCount: 0)
            ).contains("before any data arrived")
        )
        #expect(
            CloudSyncFeedbackSupport.manualRefreshErrorMessage(
                for: CloudSyncManualRefreshError.stalled(receivedRecordCount: 151)
            ).contains("after receiving 151 items")
        )
        #expect(
            CloudSyncFeedbackSupport.manualRefreshErrorMessage(
                for: CloudSyncManualRefreshError.hardLimitReached(receivedRecordCount: 800)
            ).contains("still processing after receiving 800 items")
        )
    }

    @Test
    func corruptStoredChangeTokenIsDiscardedAndResetClearsEveryContainer() throws {
        let suiteName = "CloudKitSyncDiagnosticsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstKey = CloudKitDirectPullTokenStore.storageKey(
            containerIdentifier: "iCloud.example.first"
        )
        let secondKey = CloudKitDirectPullTokenStore.storageKey(
            containerIdentifier: "iCloud.example.second"
        )
        defaults.set(Data([0x00, 0x01]), forKey: firstKey)
        defaults.set(Data([0x02, 0x03]), forKey: secondKey)

        #expect(
            CloudKitDirectPullTokenStore.load(
                containerIdentifier: "iCloud.example.first",
                defaults: defaults
            ) == nil
        )
        #expect(defaults.data(forKey: firstKey) == nil)

        CloudKitDirectPullTokenStore.clearAll(defaults: defaults)
        #expect(defaults.data(forKey: secondKey) == nil)
    }

    @Test
    func manualRefreshResetsInactivityOnProgressAndSavesTokenOnlyAfterMerge() throws {
        let fetcherSource = try SourceInspectionSupport.readProjectFile(
            "SharedCore/Sync/CloudKitDirectPullFetcher.swift"
        )
        let serviceSource = try SourceInspectionSupport.readProjectFile(
            "SharedCore/Sync/CloudKitDirectPullService.swift"
        )

        let changedStart = try #require(fetcherSource.range(of: "func recordChanged"))
        let changedEnd = try #require(
            fetcherSource.range(of: "func recordDeleted", range: changedStart.upperBound..<fetcherSource.endIndex)
        )
        let deletedEnd = try #require(
            fetcherSource.range(of: "func recordActivity", range: changedEnd.upperBound..<fetcherSource.endIndex)
        )
        #expect(
            fetcherSource[changedStart.lowerBound..<changedEnd.lowerBound]
                .contains("resetIdleTimeoutLocked()")
        )
        #expect(
            fetcherSource[changedEnd.lowerBound..<deletedEnd.lowerBound]
                .contains("resetIdleTimeoutLocked()")
        )
        #expect(fetcherSource.contains("requestState.recordFailure(error)"))
        #expect(fetcherSource.contains("if let firstRecordError = self.firstRecordError"))
        #expect(
            fetcherSource.contains(
                "progress.receivedRecordCount - lastReportedRecordCount >= 25"
            )
        )

        let mergeCall = try #require(
            serviceSource.range(of: "try merge(result: result, into: modelContext)")
        )
        let tokenSave = try #require(
            serviceSource.range(of: "CloudKitDirectPullTokenStore.save(")
        )
        #expect(mergeCall.upperBound <= tokenSave.lowerBound)
    }

    @Test
    func partialFailureDescribesAnonymizedRecordSpecificErrors() {
        let recordID = CKRecord.ID(recordName: "private-record-name")
        let childError = CKError(.serverRejectedRequest)
        let error = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: [recordID: childError]]
        )

        let description = CloudKitSyncDiagnostics.describe(error)

        #expect(description.contains("ckCode=2"))
        #expect(description.contains("partialCount=1"))
        #expect(description.contains("record#"))
        #expect(description.contains("ckName=CKErrorCode(rawValue: \(CKError.Code.serverRejectedRequest.rawValue))"))
        #expect(!description.contains("private-record-name"))
    }
}
