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
    func visibleBlockingModesHideAwayAndSleepWhenAwayExperimentIsOff() {
        #expect(ProtectionBlockingMode.visibleCases(includingAway: false) == [.focus])
        #expect(ProtectionBlockingMode.visibleCases(includingAway: true) == [.focus, .away, .sleep])
    }

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
    func blockedWebsiteDomainNormalization_acceptsDomainsAndURLs() throws {
        #expect(BlockingWebsiteDomain.normalizedDomain(from: "youtube.com") == "youtube.com")
        #expect(BlockingWebsiteDomain.normalizedDomain(from: " https://www.youtube.com/watch?v=123 ") == "www.youtube.com")
        #expect(BlockingWebsiteDomain.normalizedDomain(from: "*.reddit.com") == "reddit.com")
        #expect(BlockingWebsiteDomain.normalizedDomain(from: "bad domain") == nil)

        let website = try #require(FocusShieldSupport.blockedWebsiteDomain(from: "https://x.com/home"))
        #expect(website.domain == "x.com")
        #expect(website.enabledModes == ProtectionBlockingMode.defaultEnabledModes)
    }

    @Test
    func blockedWebsiteDomainStorage_deduplicatesAndPreservesModes() {
        let previousDomains = SharedDefaults.app[.appSettingBlockingWebsiteDomains]
        defer {
            SharedDefaults.app[.appSettingBlockingWebsiteDomains] = previousDomains
        }

        FocusShieldSupport.saveBlockedWebsiteDomains([
            BlockingWebsiteDomain(domain: "https://www.youtube.com/watch?v=123", enabledModes: [.focus]),
            BlockingWebsiteDomain(domain: "www.youtube.com", enabledModes: [.away]),
            BlockingWebsiteDomain(domain: "reddit.com", enabledModes: [.sleep]),
        ])

        let domains = FocusShieldSupport.loadBlockedWebsiteDomains()

        #expect(domains.map(\.domain) == ["reddit.com", "www.youtube.com"])
        #expect(domains.first { $0.domain == "www.youtube.com" }?.enabledModes == [.focus])
        #expect(FocusShieldSupport.blockedWebsiteDomainsSummaryText(domains) == "2 websites entered")
        #expect(FocusShieldSupport.blockedWebsiteDomainsSummaryText([]) == "No websites entered")
    }

    @Test
    func blockedWebsiteDomainStorage_migratesOlderSelectionsToAllProtectedModes() throws {
        let previousDomains = SharedDefaults.app[.appSettingBlockingWebsiteDomains]
        defer {
            SharedDefaults.app[.appSettingBlockingWebsiteDomains] = previousDomains
        }

        SharedDefaults.app[.appSettingBlockingWebsiteDomains] = """
        [{"domain":"example.com"}]
        """

        let domain = try #require(FocusShieldSupport.loadBlockedWebsiteDomains().first)

        #expect(domain.domain == "example.com")
        #expect(domain.enabledModes == ProtectionBlockingMode.defaultEnabledModes)
    }

    @Test
    func shouldBlockWebsiteURL_matchesExactHostsAndSubdomainsOnly() {
        let domains = [
            BlockingWebsiteDomain(domain: "youtube.com"),
            BlockingWebsiteDomain(domain: "reddit.com"),
            BlockingWebsiteDomain(domain: "coinmarketcap.com"),
        ]

        #expect(FocusShieldSupport.shouldBlockWebsiteURL("https://youtube.com/watch?v=123", against: domains))
        #expect(FocusShieldSupport.shouldBlockWebsiteURL("https://m.youtube.com/watch?v=123", against: domains))
        #expect(FocusShieldSupport.shouldBlockWebsiteURL("old.reddit.com", against: domains))
        #expect(FocusShieldSupport.shouldBlockWebsiteURL("https://coinmarketcap.com/currencies/bitcoin/", against: domains))
        #expect(FocusShieldSupport.shouldBlockWebsiteURL("https://www.coinmarketcap.com/", against: domains))
        #expect(!FocusShieldSupport.shouldBlockWebsiteURL("https://notyoutube.com", against: domains))
        #expect(!FocusShieldSupport.shouldBlockWebsiteURL("https://youtube.com.example.org", against: domains))
        #expect(!FocusShieldSupport.shouldBlockWebsiteURL("https://fakecoinmarketcap.com", against: domains))
    }

    @Test @MainActor
    func macWebsiteBlockingSupportsCommonChromiumBrowsers() {
        let bundleIdentifiers = FocusShieldSupport.supportedMacWebsiteBrowserBundleIdentifiers()

        #expect(bundleIdentifiers.contains("com.google.Chrome"))
        #expect(bundleIdentifiers.contains("com.google.Chrome.beta"))
        #expect(bundleIdentifiers.contains("com.google.Chrome.dev"))
        #expect(bundleIdentifiers.contains("com.google.Chrome.canary"))
        #expect(bundleIdentifiers.contains("com.microsoft.edgemac"))
    }

    @Test
    func macWebsiteBlockingIsAvailableInSandboxAndTestMode() {
        #expect(FocusShieldSupport.isMacWebsiteBlockingAvailable)
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
