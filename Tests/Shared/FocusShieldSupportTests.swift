import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

#if os(macOS)
@Suite(.serialized)
struct FocusShieldSupportTests {
    @Test
    func blockingModeStorageDefaultsToAllProtectedModesAndPersistsEmptySelection() {
        let key = UserDefaultStringValueKey.appSettingProtectionBlockingEnabledModes.rawValue
        let previousValue = SharedDefaults.app.object(forKey: key)
        defer {
            if let previousValue {
                SharedDefaults.app.set(previousValue, forKey: key)
            } else {
                SharedDefaults.app.removeObject(forKey: key)
            }
        }

        SharedDefaults.app.removeObject(forKey: key)
        #expect(FocusShieldSupport.loadEnabledBlockingModes() == ProtectionBlockingMode.defaultEnabledModes)

        FocusShieldSupport.saveEnabledBlockingModes([.focus, .sleep])
        #expect(FocusShieldSupport.loadEnabledBlockingModes() == [.focus, .sleep])
        #expect(FocusShieldSupport.enabledBlockingModesSummaryText([.focus, .sleep]) == "Focus, Sleep")

        FocusShieldSupport.saveEnabledBlockingModes([])
        #expect(FocusShieldSupport.loadEnabledBlockingModes().isEmpty)
        #expect(FocusShieldSupport.enabledBlockingModesSummaryText([]) == "No modes")
    }

    @Test
    func macFocusAppBlockingDefaultsToEnabledButHonorsUserDisable() {
        let key = UserDefaultBoolValueKey.appSettingMacFocusAppBlockingEnabled.rawValue
        let previousValue = SharedDefaults.app.object(forKey: key)
        defer {
            if let previousValue {
                SharedDefaults.app.set(previousValue, forKey: key)
            } else {
                SharedDefaults.app.removeObject(forKey: key)
            }
        }

        SharedDefaults.app.removeObject(forKey: key)
        #expect(FocusShieldSupport.isMacFocusAppBlockingEnabled)

        SharedDefaults.app[.appSettingMacFocusAppBlockingEnabled] = false
        #expect(!FocusShieldSupport.isMacFocusAppBlockingEnabled)

        SharedDefaults.app[.appSettingMacFocusAppBlockingEnabled] = true
        #expect(FocusShieldSupport.isMacFocusAppBlockingEnabled)
    }

    @Test
    func macBlockedAppsStorage_deduplicatesAndSummarizesSelections() {
        let previousApps = SharedDefaults.app[.appSettingMacFocusBlockedApps]
        defer {
            SharedDefaults.app[.appSettingMacFocusBlockedApps] = previousApps
        }

        FocusShieldSupport.saveMacBlockedApps([
            MacFocusBlockedApp(bundleIdentifier: "com.example.notes", displayName: "Notes", bundlePath: nil),
            MacFocusBlockedApp(bundleIdentifier: "com.example.browser", displayName: "Browser", bundlePath: nil),
            MacFocusBlockedApp(bundleIdentifier: "com.example.notes", displayName: "Notes Again", bundlePath: nil),
        ])

        let loadedApps = FocusShieldSupport.loadMacBlockedApps()

        #expect(loadedApps.map(\.bundleIdentifier) == ["com.example.browser", "com.example.notes"])
        #expect(loadedApps.allSatisfy { $0.enabledModes == ProtectionBlockingMode.defaultEnabledModes })
        #expect(FocusShieldSupport.macBlockedAppsSummaryText(loadedApps) == "2 apps selected")
        #expect(FocusShieldSupport.macBlockedAppsSummaryText([]) == "No apps selected")
    }

    @Test
    func macBlockedAppsStorage_preservesPerAppEnabledModes() throws {
        let previousApps = SharedDefaults.app[.appSettingMacFocusBlockedApps]
        defer {
            SharedDefaults.app[.appSettingMacFocusBlockedApps] = previousApps
        }

        FocusShieldSupport.saveMacBlockedApps([
            MacFocusBlockedApp(
                bundleIdentifier: "com.example.browser",
                displayName: "Browser",
                bundlePath: nil,
                enabledModes: [.focus]
            ),
        ])

        let app = try #require(FocusShieldSupport.loadMacBlockedApps().first)

        #expect(app.bundleIdentifier == "com.example.browser")
        #expect(app.enabledModes == [.focus])
    }

    @Test
    func macBlockedAppsStorage_migratesOlderSelectionsToAllProtectedModes() throws {
        let previousApps = SharedDefaults.app[.appSettingMacFocusBlockedApps]
        defer {
            SharedDefaults.app[.appSettingMacFocusBlockedApps] = previousApps
        }

        SharedDefaults.app[.appSettingMacFocusBlockedApps] = """
        [{"bundleIdentifier":"com.example.legacy","displayName":"Legacy","bundlePath":null}]
        """

        let app = try #require(FocusShieldSupport.loadMacBlockedApps().first)

        #expect(app.bundleIdentifier == "com.example.legacy")
        #expect(app.enabledModes == ProtectionBlockingMode.defaultEnabledModes)
    }
}
#endif
