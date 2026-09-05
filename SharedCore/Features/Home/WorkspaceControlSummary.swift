import Foundation

enum WorkspaceControlCategory: String, Equatable, Hashable, Sendable {
    case filter
    case view
    case sort
    case appearance
}
struct WorkspaceControlSummaryItem: Equatable, Hashable, Sendable {
    let category: WorkspaceControlCategory
    let title: String
}

struct WorkspaceControlSummary: Equatable, Sendable {
    var items: [WorkspaceControlSummaryItem]

    static let empty = WorkspaceControlSummary(items: [])

    var isEmpty: Bool {
        items.isEmpty
    }

    var preferredCategory: WorkspaceControlCategory? {
        items.first?.category
    }

    func text(maximumItemCount: Int) -> String? {
        guard maximumItemCount > 0, !items.isEmpty else { return nil }
        let visibleItems = items.prefix(maximumItemCount)
        let remainderCount = items.count - visibleItems.count
        let visibleText = visibleItems.map(\.title).joined(separator: " • ")
        guard remainderCount > 0 else { return visibleText }
        return "\(visibleText) • +\(remainderCount)"
    }

    func appending(_ item: WorkspaceControlSummaryItem?) -> Self {
        guard let item else { return self }
        var copy = self
        copy.items.append(item)
        return copy
    }
}
