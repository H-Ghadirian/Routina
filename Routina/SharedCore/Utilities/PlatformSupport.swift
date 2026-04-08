import Foundation

enum AppIconOption: String, CaseIterable, Equatable, Identifiable {
    case orange
    case yellow
    case teal
    case lightBlue
    case darkBlue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .orange:
            return "Orange"
        case .yellow:
            return "Yellow"
        case .teal:
            return "Teal"
        case .lightBlue:
            return "Light Blue"
        case .darkBlue:
            return "Dark Blue"
        }
    }

    var assetName: String {
        switch self {
        case .orange:
            return "AppIconOrangePreview"
        case .yellow:
            return "AppIconYellowPreview"
        case .teal:
            return "AppIconTealPreview"
        case .lightBlue:
            return "AppIconLightBluePreview"
        case .darkBlue:
            return "AppIconDarkBluePreview"
        }
    }

    var iOSAlternateIconName: String? {
        switch self {
        case .orange:
            return nil
        case .yellow:
            return "AppIconYellow"
        case .teal:
            return "AppIconTeal"
        case .lightBlue:
            return "AppIconLightBlue"
        case .darkBlue:
            return "AppIconDarkBlue"
        }
    }

    static var persistedSelection: AppIconOption {
        guard let rawValue = SharedDefaults.app[.selectedMacAppIcon],
              let option = migratedOption(for: rawValue) else {
            return .orange
        }
        return option
    }

    static func persist(_ option: AppIconOption) {
        SharedDefaults.app[.selectedMacAppIcon] = option.rawValue
    }

    private static func migratedOption(for rawValue: String) -> AppIconOption? {
        if let option = AppIconOption(rawValue: rawValue) {
            return option
        }

        switch rawValue {
        case "blue":
            return .lightBlue
        default:
            return nil
        }
    }
}
