import CloudKit
import Foundation

enum CloudKitPushSubscriptionService {
    private static let subscriptionID = "routina.private-db.subscription.v1"

    static func ensureSubscriptionIfNeeded(containerIdentifier: String?) async {
        guard let containerIdentifier, !containerIdentifier.isEmpty else { return }

        let container = CKContainer(identifier: containerIdentifier)
        let database = container.privateCloudDatabase

        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await save(subscription: subscription, in: database)
            CloudKitSyncDiagnostics.recordSubscriptionStatus("DB subscription ready")
        } catch {
            CloudKitSyncDiagnostics.recordSubscriptionStatus("DB subscription failed: \(error.localizedDescription)")
        }
    }

    private static func save(subscription: CKSubscription, in database: CKDatabase) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifySubscriptionsOperation(
                subscriptionsToSave: [subscription],
                subscriptionIDsToDelete: []
            )
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }
}
