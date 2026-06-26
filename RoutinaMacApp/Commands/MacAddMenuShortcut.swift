import SwiftUI

enum MacAddMenuShortcut: CaseIterable, Identifiable, Equatable {
    case event
    case emotion
    case note
    case goal
    case task
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
        case .checkIn: return "Check In"
        case .away:    return "Away"
        }
    }

    var commandTitle: String {
        switch self {
        case .checkIn:
            return "Check In"
        case .away:
            return "Start Away"
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
        if placesEnabled {
            actions.append(.checkIn)
        }
        if awayEnabled {
            actions.append(.away)
        }
        return actions
    }
}
