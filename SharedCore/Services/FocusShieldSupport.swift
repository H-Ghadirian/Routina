import Foundation
import SwiftData

#if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
#endif
#if os(macOS)
import AppKit
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
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        guard hasActiveFocusSession(in: context) else {
            clearShield()
            return
        }

        _ = applyShieldForCurrentSelection()
        #elseif os(macOS)
        guard hasActiveFocusSession(in: context) else {
            MacFocusAppBlocker.shared.stop()
            return
        }

        MacFocusAppBlocker.shared.sync()
        #endif
    }

    @MainActor
    private static func hasActiveFocusSession(in context: ModelContext) -> Bool {
        let predicate = #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        }
        var descriptor = FetchDescriptor<FocusSession>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first != nil
        } catch {
            NSLog("Focus shield active-session check failed: \(error.localizedDescription)")
            return false
        }
    }
}

#if os(macOS)
struct MacFocusBlockedApp: Codable, Equatable, Hashable, Identifiable, Sendable {
    var bundleIdentifier: String
    var displayName: String
    var bundlePath: String?

    var id: String { bundleIdentifier }
}

extension FocusShieldSupport {
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
                    bundlePath: app.bundlePath
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

    func sync() {
        let apps = FocusShieldSupport.loadMacBlockedApps()
        guard SharedDefaults.app[.appSettingMacFocusAppBlockingEnabled], !apps.isEmpty else {
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
    static func applyShieldForCurrentSelection() -> Bool {
        guard SharedDefaults.app[.appSettingFocusShieldEnabled],
              authorizationState() == .approved else {
            clearShield()
            return false
        }

        let selection = loadSelection()
        guard !selection.routinaIsEmpty else {
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
        return true
    }

    @MainActor
    static func clearShield() {
        store.shield.applications = nil
        store.shield.webDomains = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
    }
}

extension FamilyActivitySelection {
    var routinaIsEmpty: Bool {
        applicationTokens.isEmpty
            && categoryTokens.isEmpty
            && webDomainTokens.isEmpty
    }

    var routinaSummaryText: String {
        var parts: [String] = []

        if !applicationTokens.isEmpty {
            parts.append(applicationTokens.count == 1 ? "1 app" : "\(applicationTokens.count) apps")
        }
        if !webDomainTokens.isEmpty {
            parts.append(webDomainTokens.count == 1 ? "1 website" : "\(webDomainTokens.count) websites")
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
