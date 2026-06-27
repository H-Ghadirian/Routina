import Foundation

struct RoutinaSubscriptionClient: Sendable {
    var currentEntitlement: @Sendable () async -> RoutinaSubscriptionEntitlement
    var loadProducts: @Sendable () async throws -> [RoutinaSubscriptionProduct]
    var purchase: @Sendable (_ productID: String) async throws -> RoutinaSubscriptionEntitlement
    var restorePurchases: @Sendable () async throws -> RoutinaSubscriptionEntitlement
    var entitlementUpdates: @Sendable () -> AsyncStream<RoutinaSubscriptionEntitlement>
}

extension RoutinaSubscriptionClient {
    static let live = RoutinaSubscriptionClient(
        currentEntitlement: {
            await RoutinaSubscriptionStore.currentEntitlement()
        },
        loadProducts: {
            try await RoutinaSubscriptionStore.loadProducts()
        },
        purchase: { productID in
            try await RoutinaSubscriptionStore.purchase(productID: productID)
        },
        restorePurchases: {
            try await RoutinaSubscriptionStore.restorePurchases()
        },
        entitlementUpdates: {
            RoutinaSubscriptionStore.entitlementUpdates()
        }
    )

    static let unlocked = RoutinaSubscriptionClient(
        currentEntitlement: {
            .unlimited(plan: .lifetime, productID: "routina.testing.unlimited")
        },
        loadProducts: {
            RoutinaSubscriptionProduct.fallbackProducts()
        },
        purchase: { productID in
            .unlimited(plan: RoutinaSubscriptionPlan(productID: productID) ?? .lifetime, productID: productID)
        },
        restorePurchases: {
            .unlimited(plan: .lifetime, productID: "routina.testing.unlimited")
        },
        entitlementUpdates: {
            AsyncStream { continuation in
                continuation.yield(.unlimited(plan: .lifetime, productID: "routina.testing.unlimited"))
                continuation.finish()
            }
        }
    )

    static let free = RoutinaSubscriptionClient(
        currentEntitlement: { .free },
        loadProducts: {
            RoutinaSubscriptionProduct.fallbackProducts()
        },
        purchase: { _ in .free },
        restorePurchases: { .free },
        entitlementUpdates: {
            AsyncStream { continuation in
                continuation.yield(.free)
                continuation.finish()
            }
        }
    )
}

