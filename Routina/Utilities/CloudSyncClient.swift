import Foundation
import SwiftData

struct CloudSyncClient: Sendable {
    var pullLatestIntoLocalStore: @MainActor @Sendable (_ modelContext: ModelContext) async throws -> Void
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
