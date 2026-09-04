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
    func productionArchivesRequireAnAcknowledgedCloudKitSchemaDeployment() throws {
        let guardScript = try Self.sourceFile("script/cloudkit_schema_guard.sh")
        #expect(guardScript.contains("--xcode-build"))
        #expect(guardScript.contains("CloudKit Dashboard"))
        #expect(guardScript.contains("--acknowledge-production-deployment"))
        #expect(guardScript.contains("--yes-i-deployed-to-production"))
        #expect(guardScript.contains("CloudKit Production schema acknowledgement is stale."))

        let manifest = try Self.sourceFile("Config/CloudKit/production-schema.manifest")
        #expect(!manifest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        for projectPath in [
            "RoutinaMacOS.xcodeproj/project.pbxproj",
            "RoutinaiOS.xcodeproj/project.pbxproj",
        ] {
            let project = try Self.sourceFile(projectPath)
            #expect(project.contains("Verify CloudKit Production Schema"))
            #expect(project.contains(
                "shellScript = \"/bin/sh \\\"$SRCROOT/script/cloudkit_schema_guard.sh\\\" --xcode-build\\n\";"
            ))
        }
    }

    @Test
    func productionArchivesDeclareExactCloudKitInputsForXcodeScriptSandboxing() throws {
        let declaredInputs = Set(
            try Self.sourceFile("Config/CloudKit/production-schema-model-inputs.xcfilelist")
                .split(whereSeparator: \.isNewline)
                .map(String.init)
        )
        let modelDirectory = Self.projectRoot.appendingPathComponent("SharedCore/Models")
        let modelSources = try FileManager.default.subpathsOfDirectory(
            atPath: modelDirectory.path
        )
        let expectedInputs = Set(
            modelSources
                .filter { $0.hasSuffix(".swift") }
                .map { "$(SRCROOT)/SharedCore/Models/\($0)" }
        )

        #expect(declaredInputs == expectedInputs)

        for projectPath in [
            "RoutinaMacOS.xcodeproj/project.pbxproj",
            "RoutinaiOS.xcodeproj/project.pbxproj",
        ] {
            let project = try Self.sourceFile(projectPath)
            #expect(project.contains(
                "$(SRCROOT)/Config/CloudKit/production-schema-model-inputs.xcfilelist"
            ))
            #expect(project.contains(
                "$(SRCROOT)/Config/CloudKit/production-schema.manifest"
            ))
            #expect(!project.contains("\"$(SRCROOT)/Config/CloudKit\","))
        }
    }

    @Test
    func productionSchemaGuardStopsAfterSandboxReadFailures() throws {
        let guardScript = try Self.sourceFile("script/cloudkit_schema_guard.sh")
        #expect(guardScript.contains("Unable to read SwiftData model source"))
        #expect(guardScript.contains("Unable to read CloudKit Production schema manifest"))
        #expect(guardScript.contains("check the build phase's sandbox inputs"))
        #expect(!guardScript.contains("grep -cv"))
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
    func embeddedMacMCPHelperInheritsTheAppSandbox() throws {
        let helperEntitlements = try Self.propertyListDictionary(
            "Config/macOS/RoutinaAIMCPServer.entitlements"
        )
        #expect(helperEntitlements.count == 2)
        #expect(helperEntitlements["com.apple.security.app-sandbox"] as? Bool == true)
        #expect(helperEntitlements["com.apple.security.inherit"] as? Bool == true)

        let embedScript = try Self.sourceFile("script/embed_mcp_helper.sh")
        #expect(embedScript.contains(
            "entitlements_path=\"$SRCROOT/Config/macOS/RoutinaAIMCPServer.entitlements\""
        ))
        #expect(embedScript.contains("--entitlements \"$entitlements_path\""))
        #expect(embedScript.contains("--identifier \"$helper_identifier\""))
        #expect(embedScript.contains(
            "if [ \"${DEBUG_INFORMATION_FORMAT:-}\" = \"dwarf-with-dsym\" ]; then"
        ))
        #expect(embedScript.contains(
            "helper_dsym_path=\"$DWARF_DSYM_FOLDER_PATH/RoutinaAIMCPServer.dSYM\""
        ))
        #expect(embedScript.contains("dsymutil \"$destination\" -o \"$helper_dsym_path\""))
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
    func iOSInitialReleaseOmitsHealthKit() throws {
        for relativePath in [
            "Config/iOS/RoutinaiOSProd-Info.plist",
            "Config/iOS/RoutinaiOSDev-Info.plist",
        ] {
            let info = try Self.propertyListDictionary(relativePath)
            #expect(info["NSHealthShareUsageDescription"] == nil)
            #expect(info["NSHealthUpdateUsageDescription"] == nil)
        }

        for relativePath in [
            "Config/iOS/RoutinaiOS.entitlements",
            "Config/iOS/RoutinaiOSDev.entitlements",
        ] {
            let entitlements = try Self.propertyListDictionary(relativePath)
            #expect(entitlements["com.apple.developer.healthkit"] == nil)
        }

        let statsFeature = try Self.sourceFile("iOS/Features/App/AppFeature.swift")
        let statsView = try Self.sourceFile("iOS/Screens/Stats/StatsView.swift")
        #expect(!statsFeature.contains("HealthStats"))
        #expect(!statsView.contains("healthAccess"))
    }

    @Test
    func iOSReleaseTargetsOnlyIPhone() throws {
        let project = try Self.sourceFile("RoutinaiOS.xcodeproj/project.pbxproj")

        #expect(!project.contains("TARGETED_DEVICE_FAMILY = \"1,2\";"))
        #expect(project.components(separatedBy: "TARGETED_DEVICE_FAMILY = 1;").count == 13)
        #expect(project.components(separatedBy: "TARGETED_DEVICE_FAMILY = 4;").count == 5)

        for relativePath in [
            "Config/iOS/RoutinaiOSProd-Info.plist",
            "Config/iOS/RoutinaiOSDev-Info.plist",
        ] {
            let info = try Self.propertyListDictionary(relativePath)
            #expect(info["UISupportedInterfaceOrientations~ipad"] == nil)
        }
    }

    @Test
    func iOSProductionDefersFamilyControlsUntilDistributionApproval() throws {
        let productionEntitlements = try Self.propertyListDictionary(
            "Config/iOS/RoutinaiOS.entitlements"
        )
        #expect(productionEntitlements["com.apple.developer.family-controls"] == nil)

        let developmentEntitlements = try Self.propertyListDictionary(
            "Config/iOS/RoutinaiOSDev.entitlements"
        )
        #expect(developmentEntitlements["com.apple.developer.family-controls"] as? Bool == true)

        let project = try Self.sourceFile("RoutinaiOS.xcodeproj/project.pbxproj")
        #expect(project.components(separatedBy: "ROUTINA_IOS_FAMILY_CONTROLS").count == 3)

        let settingsSections = try Self.sourceFile(
            "SharedCore/Features/Settings/SettingsSectionViewSupport.swift"
        )
        #expect(settingsSections.contains("#if !os(macOS) && !ROUTINA_IOS_FAMILY_CONTROLS"))

        let settingsDetail = try Self.sourceFile(
            "iOS/Screens/Settings/SettingsIOSViews.swift"
        )
        #expect(settingsDetail.contains("#if ROUTINA_IOS_FAMILY_CONTROLS\n            SettingsBlockingDetailView()"))

        let focusShieldSupport = try Self.sourceFile("SharedCore/Services/FocusShieldSupport.swift")
        #expect(focusShieldSupport.contains(
            "#if os(iOS) && ROUTINA_IOS_FAMILY_CONTROLS && canImport(FamilyControls)"
        ))
        #expect(!focusShieldSupport.contains(
            "#if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)"
        ))
    }

    @Test
    func iOSProductionCompilesOutLocationServicesUntilPlacesShips() throws {
        let productionInfo = try Self.propertyListDictionary(
            "Config/iOS/RoutinaiOSProd-Info.plist"
        )
        #expect(productionInfo["NSLocationWhenInUseUsageDescription"] == nil)

        let developmentInfo = try Self.propertyListDictionary(
            "Config/iOS/RoutinaiOSDev-Info.plist"
        )
        #expect(developmentInfo["NSLocationWhenInUseUsageDescription"] as? String ==
            "Routina uses your location to show place-based routines when you are at the right place.")

        let project = try Self.sourceFile("RoutinaiOS.xcodeproj/project.pbxproj")
        #expect(project.components(separatedBy: "ROUTINA_IOS_LOCATION_SERVICES").count == 3)

        let locationProvider = try Self.sourceFile("iOS/Utilities/LocationProvider.swift")
        #expect(locationProvider.contains("#if ROUTINA_IOS_LOCATION_SERVICES\nimport CoreLocation"))
        #expect(locationProvider.contains("manager.requestWhenInUseAuthorization()"))

        let platformClients = try Self.sourceFile("iOS/Utilities/PlatformClients.swift")
        #expect(platformClients.contains(
            "#if ROUTINA_IOS_LOCATION_SERVICES\n            await OneShotLocationProvider()"
        ))
        #expect(platformClients.contains(
            "#else\n            _ = requestAuthorizationIfNeeded\n            return LocationSnapshot(authorizationStatus: .notDetermined)"
        ))
    }

    @Test
    func iOSProductionDefersTheWatchCompanionUntilItsReleasePhase() throws {
        let project = try Self.sourceFile("RoutinaiOS.xcodeproj/project.pbxproj")
        let productionTarget = try Self.nativeTarget(named: "RoutinaiOSProd", in: project)

        #expect(!productionTarget.contains("Embed Watch Content"))
        #expect(!productionTarget.contains("5F1000192E90000100000001"))
        #expect(project.contains("5F1000132E90000100000001 /* RoutinaWatchApp */ = {"))
        #expect(project.contains("5F1000142E90000100000001 /* RoutinaWatchExtension */ = {"))

        let rootScene = try Self.sourceFile("iOS/App/RoutinaIOSRootScene.swift")
        #expect(rootScene.contains(
            "if AppEnvironment.isDevelopmentAppVariant {\n                WatchRoutineSyncBridge.shared.startIfNeeded"
        ))
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
        try SourceInspectionSupport.readProjectFile(relativePath)
    }

    private static func nativeTarget(named name: String, in project: String) throws -> String {
        let marker = "/* \(name) */ = {\n\t\t\tisa = PBXNativeTarget;"
        let start = try #require(project.range(of: marker))
        let suffix = project[start.lowerBound...]
        let end = try #require(suffix.range(of: "\n\t\t};"))
        return String(suffix[..<end.upperBound])
    }

    private static let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
