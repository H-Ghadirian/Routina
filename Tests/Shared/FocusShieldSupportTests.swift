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
        #expect(FocusShieldSupport.macBlockedAppsSummaryText(loadedApps) == "2 apps selected")
        #expect(FocusShieldSupport.macBlockedAppsSummaryText([]) == "No apps selected")
    }
}
#endif
