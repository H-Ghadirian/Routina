import Foundation

enum RoutinaSubscriptionPlan: String, CaseIterable, Identifiable, Equatable, Sendable {
    case weekly
    case monthly
    case annual
    case lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        case .lifetime:
            return "Lifetime"
        }
    }

    var subtitle: String {
        switch self {
        case .weekly:
            return "Short-term access for busy weeks."
        case .monthly:
            return "Flexible unlimited planning."
        case .annual:
            return "Best for long-term routines."
        case .lifetime:
            return "One purchase, unlimited tasks forever."
        }
    }

    var sortOrder: Int {
        switch self {
        case .weekly:
            return 0
        case .monthly:
            return 1
        case .annual:
            return 2
        case .lifetime:
            return 3
        }
    }

    var defaultProductID: String {
        switch self {
        case .weekly:
            return "routina.unlimited.weekly"
        case .monthly:
            return "routina.unlimited.monthly"
        case .annual:
            return "routina.unlimited.annual"
        case .lifetime:
            return "routina.unlimited.lifetime"
        }
    }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID || $0.defaultProductID == productID }) else {
            return nil
        }
        self = plan
    }

    var productID: String {
        AppEnvironment.subscriptionProductID(for: self)
    }
}

struct RoutinaSubscriptionProduct: Equatable, Identifiable, Sendable {
    var id: String
    var plan: RoutinaSubscriptionPlan
    var displayName: String
    var displayPrice: String
    var periodDescription: String?

    var title: String {
        displayName.isEmpty ? plan.title : displayName
    }

    var priceSummary: String {
        if let periodDescription, !periodDescription.isEmpty {
            return "\(displayPrice) \(periodDescription)"
        }
        return displayPrice
    }

    static func fallbackProducts() -> [Self] {
        RoutinaSubscriptionPlan.allCases.map { plan in
            RoutinaSubscriptionProduct(
                id: plan.productID,
                plan: plan,
                displayName: plan.title,
                displayPrice: "Unavailable",
                periodDescription: plan == .lifetime ? "one-time" : nil
            )
        }
    }
}

enum RoutinaSubscriptionEntitlement: Equatable, Sendable {
    case free
    case unlimited(plan: RoutinaSubscriptionPlan, productID: String)

    var hasUnlimitedTasks: Bool {
        switch self {
        case .free:
            return false
        case .unlimited:
            return true
        }
    }
}

