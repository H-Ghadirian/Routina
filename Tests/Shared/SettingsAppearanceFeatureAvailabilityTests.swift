import Foundation
import Testing

struct SettingsAppearanceFeatureAvailabilityTests {
    @Test
    func iosTaskRowAppearanceFollowsGoalAndPlaceFeatureAvailability() throws {
        let settingsSource = try Self.sourceFile(
            "iOS/Screens/Settings/SettingsAppearanceDetailView.swift"
        )
        let previewSource = try Self.sourceFile(
            "SharedCore/Views/SettingsTaskRowPreviewView.swift"
        )

        #expect(settingsSource.contains("UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue"))
        #expect(settingsSource.contains("UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue"))
        #expect(settingsSource.contains("ForEach(availableTaskRowFields)"))
        #expect(settingsSource.contains("showsGoals: isGoalsTabEnabled"))
        #expect(settingsSource.contains("showsPlaces: isPlacesEnabled"))
        #expect(settingsSource.contains("Text(\"Shown: \\(taskRowSummaryText)\")"))
        #expect(previewSource.contains("showsPlaces && visibility.shows(.place)"))
        #expect(previewSource.contains("showsGoals && visibility.shows(.goals)"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
