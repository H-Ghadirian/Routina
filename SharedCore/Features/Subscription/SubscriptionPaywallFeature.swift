import ComposableArchitecture
import Foundation

enum SubscriptionPaywallResult<Value: Equatable>: Equatable {
    case success(Value)
    case failure(String)
}

@Reducer
struct SubscriptionPaywallFeature {
    @ObservableState
    struct State: Equatable {
        var limitSnapshot: RoutinaTaskLimitSnapshot
        var products: [RoutinaSubscriptionProduct] = []
        var entitlement: RoutinaSubscriptionEntitlement = .free
        var isLoadingProducts = false
        var purchaseInProgressProductID: String?
        var isRestoringPurchases = false
        var statusMessage: String?

        var visibleProducts: [RoutinaSubscriptionProduct] {
            products.isEmpty ? RoutinaSubscriptionProduct.fallbackProducts() : products
        }
    }

    enum Action: Equatable {
        case onAppear
        case entitlementUpdated(RoutinaSubscriptionEntitlement)
        case productsLoaded(SubscriptionPaywallResult<[RoutinaSubscriptionProduct]>)
        case purchaseTapped(String)
        case purchaseFinished(SubscriptionPaywallResult<RoutinaSubscriptionEntitlement>)
        case restoreTapped
        case restoreFinished(SubscriptionPaywallResult<RoutinaSubscriptionEntitlement>)
        case dismissTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case didUnlock
            case didDismiss
        }
    }

    @Dependency(\.routinaSubscriptionClient) var subscriptionClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoadingProducts = state.products.isEmpty
                return .merge(
                    .run { send in
                        let entitlement = await subscriptionClient.currentEntitlement()
                        await send(.entitlementUpdated(entitlement))
                    },
                    .run { send in
                        do {
                            let products = try await subscriptionClient.loadProducts()
                            await send(.productsLoaded(.success(products)))
                        } catch {
                            await send(.productsLoaded(.failure(error.localizedDescription)))
                        }
                    },
                    .run { send in
                        for await entitlement in subscriptionClient.entitlementUpdates() {
                            await send(.entitlementUpdated(entitlement))
                        }
                    }
                )

            case let .entitlementUpdated(entitlement):
                state.entitlement = entitlement
                guard entitlement.hasUnlimitedTasks else { return .none }
                state.statusMessage = "Unlimited tasks unlocked."
                return .send(.delegate(.didUnlock))

            case let .productsLoaded(result):
                state.isLoadingProducts = false
                switch result {
                case let .success(products):
                    state.products = products.sorted { $0.plan.sortOrder < $1.plan.sortOrder }
                    if products.isEmpty {
                        state.statusMessage = "Purchases are unavailable right now."
                    } else if state.statusMessage == "Purchases are unavailable right now." {
                        state.statusMessage = nil
                    }
                case let .failure(message):
                    state.statusMessage = message
                }
                return .none

            case let .purchaseTapped(productID):
                state.purchaseInProgressProductID = productID
                state.statusMessage = nil
                return .run { send in
                    do {
                        let entitlement = try await subscriptionClient.purchase(productID)
                        await send(.purchaseFinished(.success(entitlement)))
                    } catch {
                        await send(.purchaseFinished(.failure(error.localizedDescription)))
                    }
                }

            case let .purchaseFinished(result):
                state.purchaseInProgressProductID = nil
                switch result {
                case let .success(entitlement):
                    state.entitlement = entitlement
                    if entitlement.hasUnlimitedTasks {
                        state.statusMessage = "Unlimited tasks unlocked."
                        return .send(.delegate(.didUnlock))
                    }
                    state.statusMessage = "Purchase finished, but unlimited tasks are not active yet."
                case let .failure(message):
                    state.statusMessage = message
                }
                return .none

            case .restoreTapped:
                state.isRestoringPurchases = true
                state.statusMessage = nil
                return .run { send in
                    do {
                        let entitlement = try await subscriptionClient.restorePurchases()
                        await send(.restoreFinished(.success(entitlement)))
                    } catch {
                        await send(.restoreFinished(.failure(error.localizedDescription)))
                    }
                }

            case let .restoreFinished(result):
                state.isRestoringPurchases = false
                switch result {
                case let .success(entitlement):
                    state.entitlement = entitlement
                    if entitlement.hasUnlimitedTasks {
                        state.statusMessage = "Unlimited tasks unlocked."
                        return .send(.delegate(.didUnlock))
                    }
                    state.statusMessage = "No active purchase was found."
                case let .failure(message):
                    state.statusMessage = message
                }
                return .none

            case .dismissTapped:
                return .send(.delegate(.didDismiss))

            case .delegate:
                return .none
            }
        }
    }
}
