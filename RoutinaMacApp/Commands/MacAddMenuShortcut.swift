import SwiftUI

enum MacAddMenuShortcut: CaseIterable, Identifiable, Equatable {
    case event
    case emotion
    case note
    case goal
    case task
    case focus
    case checkIn
    case away

    var id: Self { self }

    var title: String {
        switch self {
        case .event:   return "Event"
        case .emotion: return "Emotion"
        case .note:    return "Note"
        case .goal:    return "Goal"
        case .task:    return "Task"
        case .focus:   return "Focus"
        case .checkIn: return "Check In"
        case .away:    return "Away"
        }
    }

    var menuTitle: String {
        switch self {
        case .task:
            return "Add New Task"
        default:
            return title
        }
    }

    var commandTitle: String {
        switch self {
        case .task:
            return "Add New Task"
        case .checkIn:
            return "Check In"
        case .away:
            return "Start Away"
        case .focus:
            return "Focus"
        default:
            return "New \(title)"
        }
    }

    var detail: String {
        switch self {
        case .event:
            return "Create a timeline event."
        case .emotion:
            return "Log an emotion."
        case .note:
            return "Create a note."
        case .goal:
            return "Create a goal."
        case .task:
            return "Open full task creation."
        case .focus:
            return "Choose a task, tag, and duration for focused work."
        case .checkIn:
            return "Open Places for a check-in."
        case .away:
            return "Start Away mode."
        }
    }

    var systemImage: String {
        switch self {
        case .event:   return "calendar.badge.plus"
        case .emotion: return "face.smiling"
        case .note:    return "note.text"
        case .goal:    return "target"
        case .task:    return "checklist"
        case .focus:   return "play.fill"
        case .checkIn: return "mappin.and.ellipse"
        case .away:    return "lock.shield.fill"
        }
    }

    var keyEquivalent: KeyEquivalent {
        switch self {
        case .event:   return "e"
        case .emotion: return "m"
        case .note:    return "n"
        case .goal:    return "g"
        case .task:    return "t"
        case .focus:   return "f"
        case .checkIn: return "c"
        case .away:    return "a"
        }
    }

    var modifiers: EventModifiers {
        [.control, .option, .command]
    }

    var titleWithShortcut: String {
        "\(title) \(shortcutTitle)"
    }

    var shortcutTitle: String {
        "⌃⌥⌘\(keyTitle)"
    }

    private var keyTitle: String {
        switch self {
        case .event:   return "E"
        case .emotion: return "M"
        case .note:    return "N"
        case .goal:    return "G"
        case .task:    return "T"
        case .focus:   return "F"
        case .checkIn: return "C"
        case .away:    return "A"
        }
    }

    static func visibleActions(
        eventEmotionEnabled: Bool,
        notesEnabled: Bool,
        goalsEnabled: Bool,
        placesEnabled: Bool,
        awayEnabled: Bool
    ) -> [MacAddMenuShortcut] {
        var actions: [MacAddMenuShortcut] = []
        if eventEmotionEnabled {
            actions.append(.event)
            actions.append(.emotion)
        }
        if notesEnabled {
            actions.append(.note)
        }
        if goalsEnabled {
            actions.append(.goal)
        }
        actions.append(.task)
        actions.append(.focus)
        if placesEnabled {
            actions.append(.checkIn)
        }
        if awayEnabled {
            actions.append(.away)
        }
        return actions
    }
}

enum MacFocusMenuAvailability: Equatable {
    case available
    case noStartableTasks
    case activeFocus
    case activeSprintFocus

    static func resolve(
        hasStartableTasks: Bool,
        hasActiveFocus: Bool,
        hasActiveSprintFocus: Bool
    ) -> Self {
        if hasActiveFocus {
            return .activeFocus
        }
        if hasActiveSprintFocus {
            return .activeSprintFocus
        }
        if !hasStartableTasks {
            return .noStartableTasks
        }
        return .available
    }

    var isDisabled: Bool {
        self != .available
    }

    var helpText: String {
        switch self {
        case .available:
            return MacAddMenuShortcut.focus.detail
        case .noStartableTasks:
            return "Add an active task before starting Focus."
        case .activeFocus:
            return "Manage the active Focus timer from the timer menu."
        case .activeSprintFocus:
            return "Finish the active sprint timer before starting Focus."
        }
    }
}
