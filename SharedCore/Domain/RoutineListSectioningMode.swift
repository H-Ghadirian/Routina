import Foundation

enum RoutineListSectioningMode: String, CaseIterable, Equatable, Identifiable {
    case status
    case deadlineDate

    static let defaultValue: Self = .status

    var id: Self { self }

    var title: String {
        switch self {
        case .status:
            return "Status"
        case .deadlineDate:
            return "Deadline Date"
        }
    }

    var subtitle: String {
        switch self {
        case .status:
            return "Shows Due Soon, On Track, and Done Today."
        case .deadlineDate:
            return "Keeps Due Soon, then groups the rest by deadline date."
        }
    }

    var summaryText: String {
        switch self {
        case .status:
            return "Status"
        case .deadlineDate:
            return "Deadline Date"
        }
    }
}
