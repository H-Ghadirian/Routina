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
            return "Shows linked routines and done counts side by side."
        case .combinedTotal:
            return "Shows one number for linked routines plus done counts."
        case .linkedOnly:
            return "Shows only how many routines use each tag."
        case .doneOnly:
            return "Shows only how many times tagged routines were done."
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
