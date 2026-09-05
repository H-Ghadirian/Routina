import Foundation

enum RoutinaQuickAddError: LocalizedError, Equatable {
    case emptyInput
    case duplicateTaskName(String)
    case taskNotFound(String?)
    case taskAlreadyCompleted(String)
    case checklistCompletionRequiresApp(String)
    case activeFocusSession(String?)
    case activeSleepSession
    case activeAwaySession
    case invalidFocusDuration

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Enter a task to add."
        case let .duplicateTaskName(name):
            return "\"\(name)\" already exists."
        case let .taskNotFound(name):
            if let name, !name.isEmpty {
                return "No task matching \"\(name)\" was found."
            }
            return "No due task was found."
        case let .taskAlreadyCompleted(name):
            return "\"\(name)\" is already done."
        case let .checklistCompletionRequiresApp(name):
            return "\"\(name)\" uses checklist steps. Open Routina to choose the items to complete."
        case let .activeFocusSession(name):
            if let name {
                return "A focus session is already active for \"\(name)\"."
            }
            return "A focus session is already active."
        case .activeSleepSession:
            return "Sleep mode is active. Wake up before starting focus."
        case .activeAwaySession:
            return "Away mode is active. End away time before starting focus."
        case .invalidFocusDuration:
            return "Choose a focus duration from 1 to 720 minutes."
        }
    }
}

struct RoutinaQuickAddCreateResult: Equatable, Sendable {
    var taskID: UUID
    var taskName: String
    var draft: RoutinaQuickAddDraft
    var matchedPlaceName: String?
}

struct RoutinaQuickAddCompletionResult: Equatable, Sendable {
    var taskID: UUID
    var taskName: String
    var message: String
}

struct RoutinaQuickAddFocusResult: Equatable, Sendable {
    var sessionID: UUID
    var taskID: UUID
    var taskName: String
    var durationMinutes: Int
}
