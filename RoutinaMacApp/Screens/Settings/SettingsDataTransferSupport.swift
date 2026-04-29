import SwiftUI

enum SettingsMacSection: String, CaseIterable, Identifiable, Hashable {
    case notifications
    case calendar
    case places
    case tags
    case appearance
    case iCloud
    case git
    case backup
    case support
    case about

    var id: String { rawValue }

    static func visibleSections(isGitFeaturesEnabled: Bool) -> [SettingsMacSection] {
        allCases.filter { section in
            section != .git || isGitFeaturesEnabled
        }
    }

    var title: String {
        switch self {
        case .notifications: return "Notifications"
        case .calendar:      return "Calendar"
        case .places:        return "Places"
        case .tags:          return "Tags"
        case .appearance:    return "Appearance"
        case .iCloud:        return "iCloud"
        case .git:           return "Git"
        case .backup:        return "Data Backup"
        case .support:       return "Support"
        case .about:         return "About"
        }
    }

    var icon: String {
        switch self {
        case .notifications: return "bell.badge.fill"
        case .calendar:      return "calendar.badge.plus"
        case .places:        return "mappin.and.ellipse"
        case .tags:          return "tag.fill"
        case .appearance:    return "app.badge.fill"
        case .iCloud:        return "icloud.fill"
        case .git:           return "arrow.triangle.branch"
        case .backup:        return "externaldrive.fill"
        case .support:       return "envelope.fill"
        case .about:         return "info.circle.fill"
        }
    }

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
        case .support:       return .green
        case .about:         return .gray
        }
    }
}
