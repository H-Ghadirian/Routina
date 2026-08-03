import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct AppStoreComplianceConfigurationTests {
    @Test
    func productionBundlesDeclareThatTheyDoNotUseNonExemptEncryption() throws {
        for relativePath in [
            "Config/macOS/RoutinaMacOSProd-Info.plist",
            "Config/iOS/RoutinaiOSProd-Info.plist",
        ] {
            let data = try Data(contentsOf: Self.projectRoot.appendingPathComponent(relativePath))
            let propertyList = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
            let dictionary = try #require(propertyList as? [String: Any])
            let usesNonExemptEncryption = try #require(
                dictionary["ITSAppUsesNonExemptEncryption"] as? Bool
            )

            #expect(usesNonExemptEncryption == false)
        }
    }

    @Test
    func productionMacBundleUsesOnlyReleaseVisibleSensitiveCapabilities() throws {
        let prohibitedEntitlements = [
            "com.apple.security.automation.apple-events",
            "com.apple.security.device.audio-input",
            "com.apple.security.personal-information.location",
        ]

        for relativePath in [
            "Config/macOS/RoutinaMacOSProd.entitlements",
            "Config/macOS/RoutinaMacOSProdRelease.entitlements",
        ] {
            let dictionary = try Self.propertyListDictionary(relativePath)
            for entitlement in prohibitedEntitlements {
                #expect(dictionary[entitlement] == nil)
            }
            #expect(dictionary["com.apple.security.personal-information.calendars"] as? Bool == true)
        }

        let developmentEntitlements = try Self.propertyListDictionary(
            "Config/macOS/RoutinaMacOSDev.entitlements"
        )
        for entitlement in prohibitedEntitlements {
            #expect(developmentEntitlements[entitlement] as? Bool == true)
        }

        let macProject = try Self.sourceFile("RoutinaMacOS.xcodeproj/project.pbxproj")
        #expect(!macProject.contains("ENABLE_RESOURCE_ACCESS_LOCATION = YES;"))
    }

    @Test
    func productionBundlesDoNotDeclareHiddenExperimentPermissions() throws {
        let macInfo = try Self.propertyListDictionary("Config/macOS/RoutinaMacOSProd-Info.plist")
        for key in [
            "NSAppleEventsUsageDescription",
            "NSLocationUsageDescription",
            "NSLocationWhenInUseUsageDescription",
            "NSMicrophoneUsageDescription",
        ] {
            #expect(macInfo[key] == nil)
        }

        let iOSInfo = try Self.propertyListDictionary("Config/iOS/RoutinaiOSProd-Info.plist")
        for key in ["NSLocationWhenInUseUsageDescription", "NSMicrophoneUsageDescription"] {
            #expect(iOSInfo[key] == nil)
        }
    }

    @Test
    func productionDisablesEveryExperimentalPreference() {
        for key in RoutinaExperimentalFeaturePolicy.preferenceKeys {
            #expect(
                RoutinaExperimentalFeaturePolicy.resolvedValue(
                    for: key,
                    storedValue: true,
                    isDevelopmentAppVariant: false
                ) == false
            )
            #expect(
                RoutinaExperimentalFeaturePolicy.resolvedValue(
                    for: key,
                    storedValue: true,
                    isDevelopmentAppVariant: true
                )
            )
        }

        #expect(
            RoutinaExperimentalFeaturePolicy.resolvedValue(
                for: .appSettingNotificationsEnabled,
                storedValue: true,
                isDevelopmentAppVariant: false
            )
        )
    }

    @Test
    func productionSettingsDoNotExposeBetaExperiments() throws {
        let macSettings = try Self.sourceFile(
            "RoutinaMacApp/Screens/Settings/SettingsMacDataSupportDetailViews.swift"
        )
        let iOSSettings = try Self.sourceFile(
            "iOS/Screens/Settings/SettingsDataSupportDetailViews.swift"
        )

        #expect(macSettings.contains(
            "if AppEnvironment.isDevelopmentAppVariant {\n            SettingsMacBetaExperimentsCard"
        ))
        #expect(iOSSettings.contains(
            "if AppEnvironment.isDevelopmentAppVariant {\n            SettingsBetaExperimentsSection"
        ))
    }

    private static func propertyListDictionary(_ relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: projectRoot.appendingPathComponent(relativePath))
        let propertyList = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try #require(propertyList as? [String: Any])
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private static let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
