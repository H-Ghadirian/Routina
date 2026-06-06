import Foundation
import SwiftData

#if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
#endif
#if os(macOS)
import AppKit
import ApplicationServices
#endif

enum FocusShieldAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case denied
    case approved
}

enum FocusShieldSupport {
    static var isSupported: Bool {
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        true
        #elseif os(macOS)
        true
        #else
        false
        #endif
    }

    @MainActor
    static func authorizationState() -> FocusShieldAuthorizationState {
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .approved, .approvedWithDataAccess:
            return .approved
        @unknown default:
            return .denied
        }
        #else
        return .unavailable
        #endif
    }

    @MainActor
    static func requestAuthorization() async throws {
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        #endif
    }

    @MainActor
    static func syncFocusShield(using context: ModelContext) {
        guard let activeMode = activeBlockingMode(in: context),
              isBlockingEnabled(for: activeMode) else {
            clearCurrentBlocking()
            return
        }

        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        _ = applyShieldForCurrentSelection(for: activeMode)
        #elseif os(macOS)
        MacFocusAppBlocker.shared.sync(for: activeMode)
        MacWebsiteBlocker.shared.sync(for: activeMode)
        #endif
    }

    static func loadEnabledBlockingModes() -> Set<ProtectionBlockingMode> {
        ProtectionBlockingMode.decodedSet(
            from: SharedDefaults.app[.appSettingProtectionBlockingEnabledModes]
        )
    }

    static func saveEnabledBlockingModes(_ modes: Set<ProtectionBlockingMode>) {
        SharedDefaults.app[.appSettingProtectionBlockingEnabledModes] = ProtectionBlockingMode.encodedSet(modes)
    }

    static func setBlockingMode(_ mode: ProtectionBlockingMode, isEnabled: Bool) -> Set<ProtectionBlockingMode> {
        var modes = loadEnabledBlockingModes()
        if isEnabled {
            modes.insert(mode)
        } else {
            modes.remove(mode)
        }
        saveEnabledBlockingModes(modes)
        return modes
    }

    static func enabledBlockingModesSummaryText(_ modes: Set<ProtectionBlockingMode>) -> String {
        if modes.isEmpty {
            return "No modes"
        }
        if modes == ProtectionBlockingMode.defaultEnabledModes {
            return "Focus, Away, Sleep"
        }
        return ProtectionBlockingMode.allCases
            .filter { modes.contains($0) }
            .map(\.title)
            .joined(separator: ", ")
    }

    static func blockedWebsiteDomain(from input: String) -> BlockingWebsiteDomain? {
        guard let domain = BlockingWebsiteDomain.normalizedDomain(from: input) else {
            return nil
        }
        return BlockingWebsiteDomain(domain: domain)
    }

    static func loadBlockedWebsiteDomains() -> [BlockingWebsiteDomain] {
        guard let rawValue = SharedDefaults.app[.appSettingBlockingWebsiteDomains],
              let data = rawValue.data(using: .utf8),
              let domains = try? JSONDecoder().decode([BlockingWebsiteDomain].self, from: data)
        else {
            return []
        }

        return deduplicatedBlockedWebsiteDomains(domains)
    }

    static func saveBlockedWebsiteDomains(_ domains: [BlockingWebsiteDomain]) {
        let deduplicatedDomains = deduplicatedBlockedWebsiteDomains(domains)
        guard let data = try? JSONEncoder().encode(deduplicatedDomains),
              let rawValue = String(data: data, encoding: .utf8) else {
            return
        }

        SharedDefaults.app[.appSettingBlockingWebsiteDomains] = rawValue
    }

    static func blockedWebsiteDomainsSummaryText(_ domains: [BlockingWebsiteDomain]) -> String {
        switch domains.count {
        case 0:
            return "No websites entered"
        case 1:
            return "1 website entered"
        default:
            return "\(domains.count) websites entered"
        }
    }

    private static func isBlockingEnabled(for mode: ProtectionBlockingMode) -> Bool {
        loadEnabledBlockingModes().contains(mode)
    }

    private static func deduplicatedBlockedWebsiteDomains(
        _ domains: [BlockingWebsiteDomain]
    ) -> [BlockingWebsiteDomain] {
        var seenDomains: Set<String> = []
        var result: [BlockingWebsiteDomain] = []

        for item in domains {
            guard let normalizedDomain = BlockingWebsiteDomain.normalizedDomain(from: item.domain),
                  !seenDomains.contains(normalizedDomain) else {
                continue
            }

            seenDomains.insert(normalizedDomain)
            result.append(
                BlockingWebsiteDomain(
                    domain: normalizedDomain,
                    enabledModes: item.enabledModes
                )
            )
        }

        return result.sorted {
            $0.domain.localizedCaseInsensitiveCompare($1.domain) == .orderedAscending
        }
    }

    static func shouldBlockWebsiteURL(
        _ rawURL: String,
        against domains: [BlockingWebsiteDomain]
    ) -> Bool {
        guard let host = BlockingWebsiteDomain.normalizedHost(from: rawURL) else {
            return false
        }

        return domains.contains { domain in
            host == domain.domain || host.hasSuffix(".\(domain.domain)")
        }
    }

    #if os(macOS)
    @MainActor
    static func macWebsiteBlockingStatus() -> MacWebsiteBlockingStatus {
        MacWebsiteBlocker.shared.status
    }

    @MainActor
    static func supportedMacWebsiteBrowserBundleIdentifiers() -> Set<String> {
        MacWebsiteBlocker.supportedBrowserBundleIdentifiers
    }
    #endif

    @MainActor
    private static func activeBlockingMode(in context: ModelContext) -> ProtectionBlockingMode? {
        if hasActiveFocusSession(in: context) {
            return .focus
        }
        if hasActiveAwaySession(in: context) {
            return .away
        }
        if hasActiveSleepSession(in: context) {
            return .sleep
        }
        return nil
    }

    @MainActor
    private static func clearCurrentBlocking() {
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        clearShield()
        #elseif os(macOS)
        MacFocusAppBlocker.shared.stop()
        MacWebsiteBlocker.shared.stop()
        #endif
    }

    @MainActor
    private static func hasActiveFocusSession(in context: ModelContext) -> Bool {
        let predicate = #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        }
        var descriptor = FetchDescriptor<FocusSession>(predicate: predicate)
        descriptor.fetchLimit = 8

        do {
            if try context.fetch(descriptor).contains(where: { $0.pausedAt == nil }) {
                return true
            }
            return try hasActiveSprintFocusSession(in: context)
        } catch {
            NSLog("Focus shield active-session check failed: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    private static func hasActiveSprintFocusSession(in context: ModelContext) throws -> Bool {
        let predicate = #Predicate<SprintFocusSessionRecord> { session in
            session.stoppedAt == nil
        }
        var descriptor = FetchDescriptor<SprintFocusSessionRecord>(predicate: predicate)
        descriptor.fetchLimit = 8
        return try context.fetch(descriptor).contains { $0.pausedAt == nil }
    }

    @MainActor
    private static func hasActiveAwaySession(in context: ModelContext) -> Bool {
        let predicate = #Predicate<AwaySession> { session in
            session.completedAt == nil && session.endedEarlyAt == nil
        }
        var descriptor = FetchDescriptor<AwaySession>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            return try !context.fetch(descriptor).isEmpty
        } catch {
            NSLog("Focus shield active-away check failed: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    private static func hasActiveSleepSession(in context: ModelContext) -> Bool {
        let predicate = #Predicate<SleepSession> { session in
            session.endedAt == nil
        }
        var descriptor = FetchDescriptor<SleepSession>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            return try !context.fetch(descriptor).isEmpty
        } catch {
            NSLog("Focus shield active-sleep check failed: \(error.localizedDescription)")
            return false
        }
    }
}

#if os(macOS)
extension Notification.Name {
    static let routinaMacWebsiteBlockingStatusDidChange = Notification.Name(
        "RoutinaMacWebsiteBlockingStatusDidChange"
    )
}

struct MacWebsiteBlockingStatus: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case inactive
        case active
        case warning
    }

    var kind: Kind
    var message: String?

    static let inactive = MacWebsiteBlockingStatus(kind: .inactive, message: nil)
}

struct MacFocusBlockedApp: Codable, Equatable, Hashable, Identifiable, Sendable {
    var bundleIdentifier: String
    var displayName: String
    var bundlePath: String?
    var enabledModes: Set<ProtectionBlockingMode>

    var id: String { bundleIdentifier }

    init(
        bundleIdentifier: String,
        displayName: String,
        bundlePath: String?,
        enabledModes: Set<ProtectionBlockingMode> = ProtectionBlockingMode.defaultEnabledModes
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.bundlePath = bundlePath
        self.enabledModes = enabledModes
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case displayName
        case bundlePath
        case enabledModes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        displayName = try container.decode(String.self, forKey: .displayName)
        bundlePath = try container.decodeIfPresent(String.self, forKey: .bundlePath)
        let decodedModes = try container.decodeIfPresent([ProtectionBlockingMode].self, forKey: .enabledModes)
        enabledModes = decodedModes.map(Set.init) ?? ProtectionBlockingMode.defaultEnabledModes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(bundlePath, forKey: .bundlePath)
        try container.encode(
            ProtectionBlockingMode.allCases.filter { enabledModes.contains($0) },
            forKey: .enabledModes
        )
    }
}

extension FocusShieldSupport {
    static var isMacFocusAppBlockingEnabled: Bool {
        let defaultsKey = UserDefaultBoolValueKey.appSettingMacFocusAppBlockingEnabled.rawValue
        guard SharedDefaults.app.object(forKey: defaultsKey) != nil else {
            return true
        }

        return SharedDefaults.app[.appSettingMacFocusAppBlockingEnabled]
    }

    static func loadMacBlockedApps() -> [MacFocusBlockedApp] {
        guard let rawValue = SharedDefaults.app[.appSettingMacFocusBlockedApps],
              let data = rawValue.data(using: .utf8),
              let apps = try? JSONDecoder().decode([MacFocusBlockedApp].self, from: data)
        else {
            return []
        }

        return deduplicatedMacBlockedApps(apps)
    }

    static func saveMacBlockedApps(_ apps: [MacFocusBlockedApp]) {
        let deduplicatedApps = deduplicatedMacBlockedApps(apps)
        guard let data = try? JSONEncoder().encode(deduplicatedApps),
              let rawValue = String(data: data, encoding: .utf8) else {
            return
        }

        SharedDefaults.app[.appSettingMacFocusBlockedApps] = rawValue
    }

    static func macBlockedApp(from url: URL) -> MacFocusBlockedApp? {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleIdentifier.isEmpty else {
            return nil
        }

        let displayName = (
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return MacFocusBlockedApp(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName.isEmpty ? bundleIdentifier : displayName,
            bundlePath: url.path
        )
    }

    static func macBlockedAppsSummaryText(_ apps: [MacFocusBlockedApp]) -> String {
        switch apps.count {
        case 0:
            return "No apps selected"
        case 1:
            return "1 app selected"
        default:
            return "\(apps.count) apps selected"
        }
    }

    private static func deduplicatedMacBlockedApps(_ apps: [MacFocusBlockedApp]) -> [MacFocusBlockedApp] {
        var seenBundleIDs: Set<String> = []
        var result: [MacFocusBlockedApp] = []

        for app in apps {
            let bundleIdentifier = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bundleIdentifier.isEmpty,
                  !seenBundleIDs.contains(bundleIdentifier) else {
                continue
            }

            seenBundleIDs.insert(bundleIdentifier)
            result.append(
                MacFocusBlockedApp(
                    bundleIdentifier: bundleIdentifier,
                    displayName: app.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? bundleIdentifier
                        : app.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    bundlePath: app.bundlePath,
                    enabledModes: app.enabledModes
                )
            )
        }

        return result.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}

@MainActor
private final class MacFocusAppBlocker: NSObject {
    static let shared = MacFocusAppBlocker()

    private var blockedBundleIdentifiers: Set<String> = []
    private var isObservingWorkspace = false
    private var enforcementTask: Task<Void, Never>?
    private var pendingForceTerminations: Set<pid_t> = []

    private override init() {}

    func sync(for activeMode: ProtectionBlockingMode) {
        let apps = FocusShieldSupport.loadMacBlockedApps()
            .filter { $0.enabledModes.contains(activeMode) }
        guard FocusShieldSupport.isMacFocusAppBlockingEnabled, !apps.isEmpty else {
            stop()
            return
        }

        blockedBundleIdentifiers = Set(apps.map(\.bundleIdentifier))
        installWorkspaceObserversIfNeeded()
        startEnforcementTaskIfNeeded()
        enforceRunningApplications()
    }

    func stop() {
        blockedBundleIdentifiers.removeAll()
        pendingForceTerminations.removeAll()

        if isObservingWorkspace {
            NSWorkspace.shared.notificationCenter.removeObserver(
                self,
                name: NSWorkspace.didLaunchApplicationNotification,
                object: nil
            )
            NSWorkspace.shared.notificationCenter.removeObserver(
                self,
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
            isObservingWorkspace = false
        }

        enforcementTask?.cancel()
        enforcementTask = nil
    }

    private func installWorkspaceObserversIfNeeded() {
        guard !isObservingWorkspace else { return }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationShouldBeBlocked(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationShouldBeBlocked(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        isObservingWorkspace = true
    }

    private func startEnforcementTaskIfNeeded() {
        guard enforcementTask == nil else { return }
        enforcementTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                self?.enforceRunningApplications()
            }
        }
    }

    private func handleLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        enforce(app)
    }

    @objc private func applicationShouldBeBlocked(_ notification: Notification) {
        handleLaunch(notification)
    }

    private func enforceRunningApplications() {
        for app in NSWorkspace.shared.runningApplications {
            enforce(app)
        }
    }

    private func enforce(_ app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier,
              blockedBundleIdentifiers.contains(bundleIdentifier),
              bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        _ = app.hide()
        guard app.terminate() else {
            if !app.forceTerminate() {
                NSLog("Focus app blocking could not force quit \(bundleIdentifier).")
            }
            return
        }

        scheduleForceTerminationIfNeeded(for: app, bundleIdentifier: bundleIdentifier)
    }

    private func scheduleForceTerminationIfNeeded(
        for app: NSRunningApplication,
        bundleIdentifier: String
    ) {
        let processIdentifier = app.processIdentifier
        guard !pendingForceTerminations.contains(processIdentifier) else { return }
        pendingForceTerminations.insert(processIdentifier)

        Task { @MainActor [weak self, weak app] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self else { return }
            self.pendingForceTerminations.remove(processIdentifier)
            guard self.blockedBundleIdentifiers.contains(bundleIdentifier),
                  let app,
                  app.isTerminated == false else {
                return
            }

            if !app.forceTerminate() {
                NSLog("Focus app blocking could not force quit \(bundleIdentifier).")
            }
        }
    }
}

@MainActor
private final class MacWebsiteBlocker {
    static let shared = MacWebsiteBlocker()

    private static let supportedBrowserTargets: [MacBrowserAutomationTarget] = [
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            kind: .safari
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.apple.SafariTechnologyPreview",
            displayName: "Safari Technology Preview",
            kind: .safari
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.google.Chrome",
            displayName: "Google Chrome",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.google.Chrome.beta",
            displayName: "Google Chrome Beta",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.google.Chrome.dev",
            displayName: "Google Chrome Dev",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.google.Chrome.canary",
            displayName: "Google Chrome Canary",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "org.chromium.Chromium",
            displayName: "Chromium",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.brave.Browser",
            displayName: "Brave",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.microsoft.edgemac",
            displayName: "Microsoft Edge",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.microsoft.edgemac.Beta",
            displayName: "Microsoft Edge Beta",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.microsoft.edgemac.Dev",
            displayName: "Microsoft Edge Dev",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.microsoft.edgemac.Canary",
            displayName: "Microsoft Edge Canary",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.operasoftware.Opera",
            displayName: "Opera",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.operasoftware.OperaGX",
            displayName: "Opera GX",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "com.vivaldi.Vivaldi",
            displayName: "Vivaldi",
            kind: .chromium
        ),
        MacBrowserAutomationTarget(
            bundleIdentifier: "company.thebrowser.Browser",
            displayName: "Arc",
            kind: .chromium
        ),
    ]

    static var supportedBrowserBundleIdentifiers: Set<String> {
        Set(supportedBrowserTargets.map(\.bundleIdentifier))
    }

    private static var supportedBrowsersByBundleID: [String: MacBrowserAutomationTarget] {
        Dictionary(uniqueKeysWithValues: supportedBrowserTargets.map { ($0.bundleIdentifier, $0) })
    }

    private(set) var status: MacWebsiteBlockingStatus = .inactive
    private var blockedDomains: [BlockingWebsiteDomain] = []
    private var enforcementTask: Task<Void, Never>?
    private var automationCooldownUntilByBundleID: [String: Date] = [:]
    private var activeMode: ProtectionBlockingMode?

    private init() {}

    func sync(for activeMode: ProtectionBlockingMode) {
        self.activeMode = activeMode
        blockedDomains = FocusShieldSupport.loadBlockedWebsiteDomains()
            .filter { $0.enabledModes.contains(activeMode) }
        guard !blockedDomains.isEmpty else {
            stop(
                status: MacWebsiteBlockingStatus(
                    kind: .inactive,
                    message: "No websites are enabled for \(activeMode.title)."
                )
            )
            return
        }

        updateStatus(
            kind: .active,
            message: "Website blocking is active for \(activeMode.title) with \(domainCountText)."
        )
        startEnforcementTaskIfNeeded()
        enforceFrontmostBrowser()
    }

    func stop(status: MacWebsiteBlockingStatus = .inactive) {
        activeMode = nil
        blockedDomains.removeAll()
        enforcementTask?.cancel()
        enforcementTask = nil
        updateStatus(status)
    }

    private func startEnforcementTaskIfNeeded() {
        guard enforcementTask == nil else { return }
        enforcementTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled else { return }
                self?.enforceFrontmostBrowser()
            }
        }
    }

    private func enforceFrontmostBrowser() {
        guard !blockedDomains.isEmpty,
              let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              let browser = Self.supportedBrowsersByBundleID[bundleIdentifier],
              canAttemptAutomation(for: bundleIdentifier)
        else {
            return
        }

        do {
            try browser.requestAutomationPermission()
            guard let currentURL = try browser.currentURL(),
                  FocusShieldSupport.shouldBlockWebsiteURL(currentURL, against: blockedDomains) else {
                updateStatus(
                    kind: .active,
                    message: "Website blocking is active for \(activeModeTitle) and watching \(browser.displayName)."
                )
                return
            }

            try browser.redirectCurrentTabToBlank()
            updateStatus(
                kind: .active,
                message: "Blocked \(currentURL) in \(browser.displayName)."
            )
        } catch {
            automationCooldownUntilByBundleID[bundleIdentifier] = Date().addingTimeInterval(30)
            updateStatus(
                kind: .warning,
                message: "Routina could not control \(browser.displayName): \(error.localizedDescription)"
            )
            NSLog("Mac website blocking could not control \(bundleIdentifier): \(error.localizedDescription)")
        }
    }

    private func canAttemptAutomation(for bundleIdentifier: String) -> Bool {
        guard let cooldownUntil = automationCooldownUntilByBundleID[bundleIdentifier] else {
            return true
        }
        if cooldownUntil <= Date() {
            automationCooldownUntilByBundleID[bundleIdentifier] = nil
            return true
        }
        return false
    }

    private var activeModeTitle: String {
        activeMode?.title ?? "the active mode"
    }

    private var domainCountText: String {
        blockedDomains.count == 1 ? "1 website" : "\(blockedDomains.count) websites"
    }

    private func updateStatus(kind: MacWebsiteBlockingStatus.Kind, message: String?) {
        updateStatus(MacWebsiteBlockingStatus(kind: kind, message: message))
    }

    private func updateStatus(_ nextStatus: MacWebsiteBlockingStatus) {
        guard status != nextStatus else { return }
        status = nextStatus
        NotificationCenter.default.post(name: .routinaMacWebsiteBlockingStatusDidChange, object: nil)
    }
}

private struct MacBrowserAutomationTarget: Sendable {
    enum Kind: Sendable {
        case safari
        case chromium
    }

    let bundleIdentifier: String
    let displayName: String
    let kind: Kind

    func requestAutomationPermission() throws {
        var targetDescription = AEAddressDesc()
        let createStatus = bundleIdentifier.withCString { pointer in
            AECreateDesc(
                DescType(typeApplicationBundleID),
                pointer,
                bundleIdentifier.utf8.count,
                &targetDescription
            )
        }
        guard createStatus == noErr else {
            throw MacBrowserAutomationError(
                message: "Could not prepare the Automation permission request (\(createStatus))."
            )
        }
        defer {
            AEDisposeDesc(&targetDescription)
        }

        let permissionStatus = AEDeterminePermissionToAutomateTarget(
            &targetDescription,
            typeWildCard,
            typeWildCard,
            true
        )
        switch permissionStatus {
        case noErr:
            return
        case OSStatus(errAEEventNotPermitted):
            throw MacBrowserAutomationError(
                message: "Automation permission is denied. Allow Routina under System Settings > Privacy & Security > Automation."
            )
        case OSStatus(errAEEventWouldRequireUserConsent):
            throw MacBrowserAutomationError(
                message: "Automation permission is needed, but macOS did not show the permission prompt."
            )
        default:
            throw MacBrowserAutomationError(
                message: "Automation permission check failed (\(permissionStatus))."
            )
        }
    }

    func currentURL() throws -> String? {
        let script: String
        switch kind {
        case .safari:
            script = """
            tell application id "\(bundleIdentifier)"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        case .chromium:
            script = """
            tell application id "\(bundleIdentifier)"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        }

        let value = try runAppleScript(script)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func redirectCurrentTabToBlank() throws {
        let script: String
        switch kind {
        case .safari:
            script = """
            tell application id "\(bundleIdentifier)"
                if (count of windows) is 0 then return
                set URL of current tab of front window to "about:blank"
            end tell
            """
        case .chromium:
            script = """
            tell application id "\(bundleIdentifier)"
                if (count of windows) is 0 then return
                set URL of active tab of front window to "about:blank"
            end tell
            """
        }

        _ = try runAppleScript(script)
    }

    private func runAppleScript(_ source: String) throws -> String? {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw MacBrowserAutomationError(message: "Could not create browser automation script.")
        }

        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
                ?? "Browser automation was not allowed."
            throw MacBrowserAutomationError(message: message)
        }

        return result.stringValue
    }
}

private struct MacBrowserAutomationError: LocalizedError {
    var message: String

    var errorDescription: String? {
        message
    }
}
#endif

#if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
extension FocusShieldSupport {
    @MainActor private static let store = ManagedSettingsStore()

    static func loadSelection() -> FamilyActivitySelection {
        guard let encodedSelection = SharedDefaults.app[.appSettingFocusShieldSelection],
              let data = Data(base64Encoded: encodedSelection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }

        return selection
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        SharedDefaults.app[.appSettingFocusShieldSelection] = data.base64EncodedString()
    }

    @MainActor
    static func applyShieldForCurrentSelection(for mode: ProtectionBlockingMode) -> Bool {
        guard SharedDefaults.app[.appSettingFocusShieldEnabled],
              authorizationState() == .approved else {
            clearShield()
            return false
        }

        let selection = loadSelection()
        let enteredWebDomains = loadBlockedWebsiteDomains()
            .filter { $0.enabledModes.contains(mode) }
            .map { WebDomain(domain: $0.domain) }

        guard !selection.routinaIsEmpty || !enteredWebDomains.isEmpty else {
            clearShield()
            return false
        }

        store.shield.applications = selection.applicationTokens.nilIfEmpty
        store.shield.webDomains = selection.webDomainTokens.nilIfEmpty
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.webContent.blockedByFilter = enteredWebDomains.isEmpty
            ? nil
            : .specific(Set(enteredWebDomains))
        return true
    }

    @MainActor
    static func clearShield() {
        store.shield.applications = nil
        store.shield.webDomains = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        store.webContent.blockedByFilter = nil
    }
}

extension FamilyActivitySelection {
    var routinaIsEmpty: Bool {
        applicationTokens.isEmpty
            && categoryTokens.isEmpty
            && webDomainTokens.isEmpty
    }

    var routinaSummaryText: String {
        routinaSummaryText(includingEnteredWebsiteCount: 0)
    }

    func routinaSummaryText(includingEnteredWebsiteCount enteredWebsiteCount: Int) -> String {
        var parts: [String] = []

        if !applicationTokens.isEmpty {
            parts.append(applicationTokens.count == 1 ? "1 app" : "\(applicationTokens.count) apps")
        }
        let websiteCount = webDomainTokens.count + enteredWebsiteCount
        if websiteCount > 0 {
            parts.append(websiteCount == 1 ? "1 website" : "\(websiteCount) websites")
        }
        if !categoryTokens.isEmpty {
            parts.append(categoryTokens.count == 1 ? "1 category" : "\(categoryTokens.count) categories")
        }

        return parts.isEmpty ? "No apps or websites selected" : parts.joined(separator: ", ")
    }
}

private extension Set {
    var nilIfEmpty: Set<Element>? {
        isEmpty ? nil : self
    }
}
#endif
