import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct PersistenceControllerTests {
    @Test
    func primaryInitializationFailure_abortsWhenExistingStoreIsPresent() {
        let strategy = PersistenceController.strategyAfterPrimaryInitializationFailure(
            inMemory: false,
            hasExistingPersistentStore: true
        )

        #expect(strategy == .abortToProtectExistingStore)
    }

    @Test
    func primaryInitializationFailure_retriesPrimaryStoreForFreshInstall() {
        let strategy = PersistenceController.strategyAfterPrimaryInitializationFailure(
            inMemory: false,
            hasExistingPersistentStore: false
        )

        #expect(strategy == .retryPrimaryPersistentStore)
    }

    @Test
    func primaryInitializationFailure_usesFallbacksForInMemoryMode() {
        let strategy = PersistenceController.strategyAfterPrimaryInitializationFailure(
            inMemory: true,
            hasExistingPersistentStore: true
        )

        #expect(strategy == .skipRetryAndUseFallbacks)
    }

    @Test
    func storeOpenFailureMessage_includesStorePathAndUnderlyingError() {
        let message = PersistenceController.storeOpenFailureMessage(
            underlyingError: TestPersistenceError.schemaMismatch,
            storePath: "/tmp/RoutinaModel.sqlite",
            diagnosticsPath: "/tmp/PersistenceFailure.txt"
        )

        #expect(message.contains("/tmp/RoutinaModel.sqlite"))
        #expect(message.contains("schema mismatch"))
        #expect(message.contains("will not fall back to a new empty store"))
        #expect(message.contains("/tmp/PersistenceFailure.txt"))
    }

    @Test
    func storeOpenFailureDiagnosticsReport_includesTimestampAndContext() {
        let message = PersistenceController.storeOpenFailureDiagnosticsReport(
            underlyingError: TestPersistenceError.schemaMismatch,
            storePath: "/tmp/RoutinaModel.sqlite",
            now: Date(timeIntervalSince1970: 1_713_456_789)
        )

        #expect(message.contains("Routina Persistence Failure Diagnostics"))
        #expect(message.contains("Store Path: /tmp/RoutinaModel.sqlite"))
        #expect(message.contains("Underlying Error: schema mismatch"))
        #expect(message.contains("Timestamp:"))
    }

    @Test
    func writeStoreOpenFailureDiagnostics_writesReadableFile() throws {
        let diagnosticsURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("PersistenceFailure.txt")

        let writtenURL = PersistenceController.writeStoreOpenFailureDiagnostics(
            underlyingError: TestPersistenceError.schemaMismatch,
            storePath: "/tmp/RoutinaModel.sqlite",
            diagnosticsURL: diagnosticsURL,
            now: Date(timeIntervalSince1970: 1_713_456_789)
        )

        #expect(writtenURL == diagnosticsURL)

        let contents = try String(contentsOf: diagnosticsURL, encoding: .utf8)
        #expect(contents.contains("Store Path: /tmp/RoutinaModel.sqlite"))
        #expect(contents.contains("Underlying Error: schema mismatch"))
    }
}

private enum TestPersistenceError: LocalizedError {
    case schemaMismatch

    var errorDescription: String? {
        switch self {
        case .schemaMismatch:
            return "schema mismatch"
        }
    }
}
