import SwiftUI

extension SettingsSectionID {
    var tint: Color {
        switch self {
        case .general:
            return .blue
        case .devices:
            return .teal
        case .notifications:
            return .red
        case .blocking:
            return .teal
        case .calendar:
            return .purple
        case .places:
            return .blue
        case .tags:
            return .pink
        case .sections:
            return .blue
        case .appearance:
            return .orange
        case .iCloud:
            return .cyan
        case .git, .backup:
            return .indigo
        case .quickAdd:
            return .mint
        case .shortcuts:
            return .teal
        case .support, .about:
            return .green
        }
    }
}
