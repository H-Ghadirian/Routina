import SwiftUI

enum RoutineTaskColor: String, CaseIterable, Equatable, Hashable, Codable, Sendable {
    case none
    case red
    case orange
    case yellow
    case green
    case teal
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray

    var swiftUIColor: Color? {
        switch self {
        case .none:   return nil
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .teal:   return .teal
        case .blue:   return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink:   return .pink
        case .brown:  return .brown
        case .gray:   return .gray
        }
    }

    var displayName: String {
        switch self {
        case .none:   return "None"
        case .red:    return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green:  return "Green"
        case .teal:   return "Teal"
        case .blue:   return "Blue"
        case .indigo: return "Indigo"
        case .purple: return "Purple"
        case .pink:   return "Pink"
        case .brown:  return "Brown"
        case .gray:   return "Gray"
        }
    }
}
