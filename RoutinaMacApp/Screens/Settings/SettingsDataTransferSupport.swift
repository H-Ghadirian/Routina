import SwiftUI

enum SettingsMacSection: String, CaseIterable, Identifiable, Hashable {
    case notifications
    case places
    case tags
    case appearance
    case iCloud
    case github
    case gitlab
    case backup
    case support
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notifications: return "Notifications"
        case .places:        return "Places"
        case .tags:          return "Tags"
        case .appearance:    return "Appearance"
        case .iCloud:        return "iCloud"
        case .github:        return "GitHub"
        case .gitlab:        return "GitLab"
        case .backup:        return "Data Backup"
        case .support:       return "Support"
        case .about:         return "About"
        }
    }

    var icon: String {
        switch self {
        case .notifications: return "bell.badge.fill"
        case .places:        return "mappin.and.ellipse"
        case .tags:          return "tag.fill"
        case .appearance:    return "app.badge.fill"
        case .iCloud:        return "icloud.fill"
        case .github:        return "point.3.connected.trianglepath.dotted"
        case .gitlab:        return "arrow.triangle.branch"
        case .backup:        return "externaldrive.fill"
        case .support:       return "envelope.fill"
        case .about:         return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .notifications: return .red
        case .places:        return .blue
        case .tags:          return .pink
        case .appearance:    return .orange
        case .iCloud:        return .cyan
        case .github:        return .indigo
        case .gitlab:        return .orange
        case .backup:        return .indigo
        case .support:       return .green
        case .about:         return .gray
        }
    }
}
