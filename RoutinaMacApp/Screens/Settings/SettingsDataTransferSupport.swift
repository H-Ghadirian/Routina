import SwiftUI

typealias SettingsMacSection = SettingsSectionID

extension SettingsMacSection {
    var tint: Color {
        switch self {
        case .notifications: return .red
        case .calendar:      return .purple
        case .places:        return .blue
        case .tags:          return .pink
        case .appearance:    return .orange
        case .iCloud:        return .cyan
        case .git:           return .indigo
        case .backup:        return .indigo
        case .quickAdd:      return .mint
        case .shortcuts:     return .teal
        case .support:       return .green
        case .about:         return .gray
        }
    }
}
