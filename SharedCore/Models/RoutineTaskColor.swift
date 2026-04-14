import SwiftUI

enum RoutineTaskColor: Equatable, Hashable, Sendable {
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
    case custom(hex: String)

    var swiftUIColor: Color? {
        switch self {
        case .none:               return nil
        case .red:                return .red
        case .orange:             return .orange
        case .yellow:             return .yellow
        case .green:              return .green
        case .teal:               return .teal
        case .blue:               return .blue
        case .indigo:             return .indigo
        case .purple:             return .purple
        case .pink:               return .pink
        case .brown:              return .brown
        case .gray:               return .gray
        case .custom(let hex):    return Color(hex: hex)
        }
    }

    var displayName: String {
        switch self {
        case .none:               return "None"
        case .red:                return "Red"
        case .orange:             return "Orange"
        case .yellow:             return "Yellow"
        case .green:              return "Green"
        case .teal:               return "Teal"
        case .blue:               return "Blue"
        case .indigo:             return "Indigo"
        case .purple:             return "Purple"
        case .pink:               return "Pink"
        case .brown:              return "Brown"
        case .gray:               return "Gray"
        case .custom:             return "Custom"
        }
    }
}

extension RoutineTaskColor: RawRepresentable {
    var rawValue: String {
        switch self {
        case .none:               return "none"
        case .red:                return "red"
        case .orange:             return "orange"
        case .yellow:             return "yellow"
        case .green:              return "green"
        case .teal:               return "teal"
        case .blue:               return "blue"
        case .indigo:             return "indigo"
        case .purple:             return "purple"
        case .pink:               return "pink"
        case .brown:              return "brown"
        case .gray:               return "gray"
        case .custom(let hex):    return hex
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "none":    self = .none
        case "red":     self = .red
        case "orange":  self = .orange
        case "yellow":  self = .yellow
        case "green":   self = .green
        case "teal":    self = .teal
        case "blue":    self = .blue
        case "indigo":  self = .indigo
        case "purple":  self = .purple
        case "pink":    self = .pink
        case "brown":   self = .brown
        case "gray":    self = .gray
        default:
            if rawValue.hasPrefix("#") {
                self = .custom(hex: rawValue)
            } else {
                return nil
            }
        }
    }
}

extension RoutineTaskColor: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = RoutineTaskColor(rawValue: raw) ?? .none
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension RoutineTaskColor: CaseIterable {
    /// Preset named cases only — does not include `.custom`.
    static var allCases: [RoutineTaskColor] {
        [.none, .red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple, .pink, .brown, .gray]
    }
}

// MARK: - Color ↔ Hex helpers

extension Color {
    /// Initialise from a 6-digit hex string, with or without a leading `#`.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double(value         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Returns a 6-digit uppercase hex string like `#FF5733`, or `nil` if the
    /// colour cannot be expressed in the sRGB colour space.
    var hexString: String? {
#if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
#elseif canImport(AppKit)
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(rgb.redComponent   * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent  * 255))
#else
        return nil
#endif
    }
}
