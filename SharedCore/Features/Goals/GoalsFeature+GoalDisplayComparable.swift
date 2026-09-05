import Foundation

extension GoalsFeature.GoalDisplay: Comparable {
    static func < (lhs: GoalsFeature.GoalDisplay, rhs: GoalsFeature.GoalDisplay) -> Bool {
        if lhs.status != rhs.status {
            return lhs.status == .active
        }
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        switch (lhs.createdAt, rhs.createdAt) {
        case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }
}
