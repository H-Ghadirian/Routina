import CloudKit
import Foundation
import SwiftData

struct CloudSyncClient: Sendable {
    var pullLatestIntoLocalStore: @MainActor @Sendable (_ modelContext: ModelContext) async throws -> Void
}

enum CloudSyncManualRefreshError: LocalizedError, Equatable {
    case timedOut

    var errorDescription: String? {
        switch self {
        case .timedOut:
            return "iCloud did not respond in time."
        }
    }
}

enum CloudSyncFeedbackSupport {
    static func manualRefreshErrorMessage(for error: Error) -> String {
        if error as? CloudSyncManualRefreshError == .timedOut {
            return "iCloud did not respond in time. Check your internet connection and iCloud account, then try again. Your existing Routina data is safe."
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
