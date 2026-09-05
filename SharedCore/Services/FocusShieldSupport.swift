import Foundation
import SwiftData

#if os(iOS) && ROUTINA_IOS_FAMILY_CONTROLS && canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
#endif
enum FocusShieldAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case denied
    case approved
}

enum FocusShieldSupport {
    static var isSupported: Bool {
        #if os(iOS) && ROUTINA_IOS_FAMILY_CONTROLS && canImport(FamilyControls) && canImport(ManagedSettings)
        true
        #elseif os(macOS)
        true
        #else
        false
        #endif
    }

    @MainActor
    static func authorizationState() -> FocusShieldAuthorizationState {
        #if os(iOS) && ROUTINA_IOS_FAMILY_CONTROLS && canImport(FamilyControls) && canImport(ManagedSettings)
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
        #if os(iOS) && ROUTINA_IOS_FAMILY_CONTROLS && canImport(FamilyControls) && canImport(ManagedSettings)
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

        #if os(iOS) && ROUTINA_IOS_FAMILY_CONTROLS && canImport(FamilyControls) && canImport(ManagedSettings)
        _ = applyShieldForCurrentSelection(for: activeMode)
        #elseif os(macOS)
        MacFocusAppBlocker.shared.sync(for: activeMode)
        guard isMacWebsiteBlockingAvailable else {
            MacWebsiteBlocker.shared.stop()
            return
        }
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

    static func enabledBlockingModesSummaryText(
        _ modes: Set<ProtectionBlockingMode>,
        includingAway: Bool = true
    ) -> String {
        let visibleModes = ProtectionBlockingMode.visibleCases(includingAway: includingAway)
            .filter { modes.contains($0) }
        if visibleModes.isEmpty {
            return "No modes"
        }
        return visibleModes
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
    static var isMacWebsiteBlockingAvailable: Bool {
        AppEnvironment.isSandboxDataMode || SharedDefaults.app[.appSettingMacWebsiteBlockingEnabled]
    }

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
        if SharedDefaults.app[.appSettingAwayEnabled], hasActiveAwaySession(in: context) {
            return .away
        }
        if hasActiveSleepSession(in: context) {
            return .sleep
        }
        return nil
    }

    @MainActor
    private static func clearCurrentBlocking() {
        #if os(iOS) && ROUTINA_IOS_FAMILY_CONTROLS && canImport(FamilyControls) && canImport(ManagedSettings)
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

#if os(iOS) && ROUTINA_IOS_FAMILY_CONTROLS && canImport(FamilyControls) && canImport(ManagedSettings)
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
