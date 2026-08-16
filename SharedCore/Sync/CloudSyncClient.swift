import CloudKit
import Foundation
import SwiftData

struct CloudSyncClient: Sendable {
    var pullLatestIntoLocalStore: @MainActor @Sendable (_ modelContext: ModelContext) async throws -> Void
}

enum CloudSyncManualRefreshError: LocalizedError, Equatable {
    case stalled(receivedRecordCount: Int)
    case hardLimitReached(receivedRecordCount: Int)

    var errorDescription: String? {
        switch self {
        case let .stalled(receivedRecordCount):
            if receivedRecordCount == 0 {
                return "iCloud stopped responding before any data arrived."
            }
            return "iCloud stopped responding after \(receivedRecordCount) items arrived."
        case let .hardLimitReached(receivedRecordCount):
            return "iCloud refresh reached its safety limit after \(receivedRecordCount) items arrived."
        }
    }
}

struct CloudSyncManualRefreshProgress: Equatable, Sendable {
    enum Mode: String, Equatable, Sendable {
        case full
        case incremental
    }

    var mode: Mode
    var changedRecordCount: Int
    var deletedRecordCount: Int

    var receivedRecordCount: Int {
        changedRecordCount + deletedRecordCount
    }

    var displayMessage: String {
        let noun = receivedRecordCount == 1 ? "item" : "items"
        switch mode {
        case .full:
            return "Receiving iCloud data… \(receivedRecordCount) \(noun)."
        case .incremental:
            return "Receiving recent iCloud changes… \(receivedRecordCount) \(noun)."
        }
    }
}

enum CloudSyncFeedbackSupport {
    static func manualRefreshErrorMessage(for error: Error) -> String {
        if let refreshError = error as? CloudSyncManualRefreshError {
            switch refreshError {
            case let .stalled(receivedRecordCount):
                if receivedRecordCount == 0 {
                    return "iCloud stopped responding before any data arrived. Check your internet connection and iCloud account, then try again. Your existing Routina data is safe."
                }
                return "iCloud stopped responding after receiving \(receivedRecordCount) items. Check your connection, then try again. Your existing Routina data is safe."
            case let .hardLimitReached(receivedRecordCount):
                return "iCloud was still processing after receiving \(receivedRecordCount) items, but the refresh reached its safety limit. Try again on a stable connection. Your existing Routina data is safe."
            }
        }

        guard let cloudError = error as? CKError else {
            return "Routina couldn't refresh from iCloud. \(error.localizedDescription) Your existing Routina data is safe."
        }

        switch cloudError.code {
        case .notAuthenticated:
            return "Routina can't access iCloud. Check that you're signed in to iCloud, then try again. Your existing Routina data is safe."
        case .networkUnavailable, .networkFailure:
            return "Routina couldn't reach iCloud. Check your internet connection, then try again. Your existing Routina data is safe."
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return "iCloud is temporarily unavailable. Wait a moment, then try again. Your existing Routina data is safe."
        default:
            return "Routina couldn't refresh from iCloud. \(cloudError.localizedDescription) Your existing Routina data is safe."
        }
    }
}

extension CloudSyncClient {
    static let live = CloudSyncClient(
        pullLatestIntoLocalStore: { modelContext in
            guard let containerIdentifier = AppEnvironment.cloudKitContainerIdentifier else { return }
            try await CloudKitDirectPullService.pullLatestIntoLocalStore(
                containerIdentifier: containerIdentifier,
                modelContext: modelContext
            )
        }
    )
}
