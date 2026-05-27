import Foundation

enum RoutineListSectioningMode: String, CaseIterable, Equatable, Identifiable {
    case none
    case status
    case deadlineDate
    case tags

    static let defaultValue: Self = .status

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .status:
            return "Status"
        case .deadlineDate:
            return "Deadline Date"
        case .tags:
            return "Tags"
        }
    }

    var systemImage: String {
        switch self {
        case .none:
            return "list.bullet"
        case .status:
            return "list.bullet.rectangle"
        case .deadlineDate:
            return "calendar"
        case .tags:
            return "tag"
        }
    }

    var subtitle: String {
        switch self {
        case .none:
            return "Shows matching tasks in one list."
        case .status:
            return "Shows Due Soon, On Track, and Done Today."
        case .deadlineDate:
            return "Keeps Due Soon, then groups the rest by deadline date."
        case .tags:
            return "Groups active routines and todos by their first tag."
        }
    }

    var summaryText: String {
        switch self {
        case .none:
            return "None"
        case .status:
            return "Status"
        case .deadlineDate:
            return "Deadline Date"
        case .tags:
            return "Tags"
        }
    }
}
