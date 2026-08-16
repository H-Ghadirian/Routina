import CloudKit
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
    func manualRefreshOperationUsesAnInteractiveDeadline() {
        let operation = CKFetchRecordZoneChangesOperation()

        CloudKitDirectPullFetcher.configureManualRefreshOperation(operation)

        #expect(CloudKitDirectPullFetcher.manualRefreshTimeoutSeconds == 60)
        #expect(operation.configuration?.qualityOfService == .userInitiated)
        #expect(operation.configuration?.timeoutIntervalForRequest == 60)
        #expect(operation.configuration?.timeoutIntervalForResource == 60)
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
