import SwiftUI

extension Color {
    init?(routineTagHex: String?) {
        guard let routineTagHex else { return nil }
        let value = routineTagHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard hex.count == 6, let intValue = Int(hex, radix: 16) else { return nil }

        let red = Double((intValue >> 16) & 0xFF) / 255
        let green = Double((intValue >> 8) & 0xFF) / 255
        let blue = Double(intValue & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    var routineTagHex: String? {
        #if canImport(UIKit)
        let resolvedColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return Color.routineTagHex(red: red, green: green, blue: blue)
        #elseif canImport(AppKit)
        let resolvedColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        return String(
            format: "#%02X%02X%02X",
            Int((resolvedColor.redComponent * 255).rounded()),
            Int((resolvedColor.greenComponent * 255).rounded()),
            Int((resolvedColor.blueComponent * 255).rounded())
        )
        #else
        return nil
        #endif
    }

    private static func routineTagHex(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }
}

extension RoutineTagSummary {
    var displayColor: Color? {
        Color(routineTagHex: colorHex)
    }
}
