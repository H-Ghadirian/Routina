import Foundation

struct TaskLadderGroupEditorPresentation: Identifiable {
    let id = UUID()
    let group: TaskLadderGroup?
}

enum TaskRankingMacEmptyState {
    static func title(isNested: Bool) -> String {
        isNested ? "No actionable nested tasks" : "No tasks in Task Ladder"
    }

    static func description(parentName: String?) -> String {
        if let parentName {
            return "\(parentName) has no nested tasks available in Task Ladder right now."
        }
        return "Paused, blocked, completed, canceled, archived, nested, and Flag-hidden tasks stay out of the root task ladder."
    }
}
