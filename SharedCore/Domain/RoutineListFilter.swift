import Foundation

enum RoutineListFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "All"
    case due = "Due"
    case todos = "Todos"
    case doneToday = "Done Today"

    var id: String { rawValue }
}
