import Foundation

#if canImport(StoreKit)
import StoreKit
#endif

enum RoutinaSubscriptionPurchaseError: LocalizedError, Equatable {
    case productUnavailable
    case unverifiedTransaction
    case purchasePending
    case purchaseCancelled

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "This purchase is unavailable right now."
        case .unverifiedTransaction:
            return "The purchase could not be verified."
        case .purchasePending:
            return "The purchase is pending approval."
        case .purchaseCancelled:
            return "The purchase was cancelled."
        }
    }
}

enum RoutinaSubscriptionStore {
    static func loadProducts() async throws -> [RoutinaSubscriptionProduct] {
        #if canImport(StoreKit)
        let productIDs = RoutinaSubscriptionPlan.allCases.map(\.productID)
        let products = try await Product.products(for: productIDs)
        return products
            .compactMap(RoutinaSubscriptionProduct.init(product:))
            .sorted { $0.plan.sortOrder < $1.plan.sortOrder }
        #else
        return []
        #endif
    }

    static func currentEntitlement() async -> RoutinaSubscriptionEntitlement {
        if AppEnvironment.isAutomatedTestMode || AppEnvironment.unlocksAllTasks {
            return .unlimited(plan: .lifetime, productID: "routina.testing.unlimited")
        }

        #if canImport(StoreKit)
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.revocationDate == nil,
                  transaction.isRoutinaActive,
                  let plan = RoutinaSubscriptionPlan(productID: transaction.productID)
            else {
                continue
            }
            return .unlimited(plan: plan, productID: transaction.productID)
        }
        #endif

        return .free
    }

    static func purchase(productID: String) async throws -> RoutinaSubscriptionEntitlement {
        #if canImport(StoreKit)
        guard let product = try await Product.products(for: [productID]).first else {
            throw RoutinaSubscriptionPurchaseError.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case let .success(verificationResult):
            let transaction = try verified(verificationResult)
            await transaction.finish()
            return await currentEntitlement()

        case .pending:
            throw RoutinaSubscriptionPurchaseError.purchasePending

        case .userCancelled:
            throw RoutinaSubscriptionPurchaseError.purchaseCancelled

        @unknown default:
            throw RoutinaSubscriptionPurchaseError.productUnavailable
        }
        #else
        throw RoutinaSubscriptionPurchaseError.productUnavailable
        #endif
    }

    static func restorePurchases() async throws -> RoutinaSubscriptionEntitlement {
        #if canImport(StoreKit)
        try await AppStore.sync()
        #endif
        return await currentEntitlement()
    }

    static func entitlementUpdates() -> AsyncStream<RoutinaSubscriptionEntitlement> {
        AsyncStream { continuation in
            let task = Task {
                continuation.yield(await currentEntitlement())

                #if canImport(StoreKit)
                for await _ in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    continuation.yield(await currentEntitlement())
                }
                #endif
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    #if canImport(StoreKit)
    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(value):
            return value
        case .unverified:
            throw RoutinaSubscriptionPurchaseError.unverifiedTransaction
        }
    }
    #endif
}

#if canImport(StoreKit)
private extension RoutinaSubscriptionProduct {
    init?(product: Product) {
        guard let plan = RoutinaSubscriptionPlan(productID: product.id) else { return nil }
        self.init(
            id: product.id,
            plan: plan,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            periodDescription: product.subscription?.subscriptionPeriod.routinaDisplayText
                ?? (plan == .lifetime ? "one-time" : nil)
        )
    }
}

private extension Product.SubscriptionPeriod {
    var routinaDisplayText: String {
        let unitText: String
        switch unit {
        case .day:
            unitText = value == 1 ? "day" : "days"
        case .week:
            unitText = value == 1 ? "week" : "weeks"
        case .month:
            unitText = value == 1 ? "month" : "months"
        case .year:
            unitText = value == 1 ? "year" : "years"
        @unknown default:
            unitText = "period"
        }

        if value == 1 {
            return "per \(unitText)"
        }
        return "every \(value) \(unitText)"
    }
}

private extension Transaction {
    var isRoutinaActive: Bool {
        guard let expirationDate else { return true }
        return expirationDate > Date()
    }
}
#endif

