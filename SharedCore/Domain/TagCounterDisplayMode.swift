import Foundation

enum TagCounterDisplayMode: String, CaseIterable, Equatable, Identifiable, Sendable {
    case none
    case linkedAndDone
    case combinedTotal
    case linkedOnly
    case doneOnly

    static let defaultValue: Self = .none

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            return "Without Counter"
        case .linkedAndDone:
            return "Linked and Done"
        case .combinedTotal:
            return "Combined Total"
        case .linkedOnly:
            return "Linked Only"
        case .doneOnly:
            return "Done Only"
        }
    }

    var subtitle: String {
        switch self {
        case .none:
            return "Shows tag names without numbers."
        case .linkedAndDone:
            return "Shows linked repeating tasks and done counts side by side."
        case .combinedTotal:
            return "Shows one number for linked repeating tasks plus done counts."
        case .linkedOnly:
            return "Shows only how many repeating tasks use each tag."
        case .doneOnly:
            return "Shows only how many times tagged repeating tasks were done."
        }
    }

    var summaryText: String {
        switch self {
        case .none:
            return "Off"
        case .linkedAndDone:
            return "Linked + Done"
        case .combinedTotal:
            return "Combined"
        case .linkedOnly:
            return "Linked"
        case .doneOnly:
            return "Done"
        }
    }
}
