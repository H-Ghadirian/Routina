import Foundation

enum RoutineListFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "All"
    case due = "Due"
    case onMyMind = "On My Mind"
    case todos = "Todos"
    case doneToday = "Done Today"

    var id: String { rawValue }

    var title: String {
        self == .todos ? "One-time" : rawValue
    }
}
