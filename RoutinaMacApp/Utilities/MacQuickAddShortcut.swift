import Carbon
import SwiftUI

enum MacQuickAddShortcut: String, CaseIterable, Identifiable {
    case optionCommandN
    case optionSpace
    case optionCommandSpace
    case controlSpace
    case optionCommandK

    static let defaultValue: MacQuickAddShortcut = .optionCommandN

    var id: String { rawValue }

    var title: String {
        switch self {
        case .optionCommandN:
            return "⌥⌘N"
        case .optionSpace:
            return "⌥Space"
        case .optionCommandSpace:
            return "⌥⌘Space"
        case .controlSpace:
            return "⌃Space"
        case .optionCommandK:
            return "⌥⌘K"
        }
    }

    var detail: String {
        switch self {
        case .optionCommandN:
            return "Current Routina shortcut"
        case .optionSpace:
            return "Spotlight-style"
        case .optionCommandSpace:
            return "Spotlight-style with Command"
        case .controlSpace:
            return "Compact Spotlight-style"
        case .optionCommandK:
            return "Command palette style"
        }
    }

    var keyEquivalent: SwiftUI.KeyEquivalent {
        switch self {
        case .optionCommandN:
            return "n"
        case .optionSpace, .optionCommandSpace, .controlSpace:
            return " "
        case .optionCommandK:
            return "k"
        }
    }

    var eventModifiers: SwiftUI.EventModifiers {
        switch self {
        case .optionCommandN, .optionCommandSpace, .optionCommandK:
            return [.option, .command]
        case .optionSpace:
            return [.option]
        case .controlSpace:
            return [.control]
        }
    }

    var carbonKeyCode: UInt32 {
        switch self {
        case .optionCommandN:
            return UInt32(kVK_ANSI_N)
        case .optionSpace, .optionCommandSpace, .controlSpace:
            return UInt32(kVK_Space)
        case .optionCommandK:
            return UInt32(kVK_ANSI_K)
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .optionCommandN, .optionCommandSpace, .optionCommandK:
            return UInt32(optionKey | cmdKey)
        case .optionSpace:
            return UInt32(optionKey)
        case .controlSpace:
            return UInt32(controlKey)
        }
    }

    static func stored(in defaults: UserDefaults = SharedDefaults.app) -> MacQuickAddShortcut {
        guard let rawValue = defaults[.macQuickAddShortcut],
              let shortcut = MacQuickAddShortcut(rawValue: rawValue)
        else {
            return defaultValue
        }
        return shortcut
    }
}
