import Foundation

#if os(macOS)
    import AppKit

    @MainActor
    final class MacWebsiteBlocker {
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
        private var isObservingWorkspace = false
        private var enforcementActivity: NSObjectProtocol?

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
            beginEnforcementActivityIfNeeded()
            installWorkspaceObserversIfNeeded()
            startEnforcementTaskIfNeeded()
            enforceFrontmostBrowser()
        }

        func stop(status: MacWebsiteBlockingStatus = .inactive) {
            activeMode = nil
            blockedDomains.removeAll()
            enforcementTask?.cancel()
            enforcementTask = nil
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
            endEnforcementActivity()
            updateStatus(status)
        }

        private func beginEnforcementActivityIfNeeded() {
            guard enforcementActivity == nil else { return }
            enforcementActivity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated],
                reason: "Routina is enforcing website blocking during a protected mode."
            )
        }

        private func endEnforcementActivity() {
            guard let enforcementActivity else { return }
            ProcessInfo.processInfo.endActivity(enforcementActivity)
            self.enforcementActivity = nil
        }

        private func installWorkspaceObserversIfNeeded() {
            guard !isObservingWorkspace else { return }
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(browserMayNeedWebsiteBlocking(_:)),
                name: NSWorkspace.didLaunchApplicationNotification,
                object: nil
            )
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(browserMayNeedWebsiteBlocking(_:)),
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
            isObservingWorkspace = true
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

        @objc private func browserMayNeedWebsiteBlocking(_ notification: Notification) {
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleIdentifier = app.bundleIdentifier,
                Self.supportedBrowsersByBundleID[bundleIdentifier] != nil
            else {
                return
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                self?.enforceFrontmostBrowser()
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
            guard !isBlockedAsMacApp(bundleIdentifier) else {
                updateStatus(
                    kind: .active,
                    message: "Website blocking is active for \(activeModeTitle); \(browser.displayName) is blocked as an app."
                )
                return
            }

            do {
                try browser.requestAutomationPermission()
                let blockedTabs = try browser.blockedTabs(against: blockedDomains)
                guard !blockedTabs.isEmpty else {
                    updateStatus(
                        kind: .active,
                        message: "Website blocking is active for \(activeModeTitle) and watching \(browser.displayName)."
                    )
                    return
                }

                try browser.redirectTabsToBlank(blockedTabs)
                let firstURL = blockedTabs.first?.url ?? "matching website"
                updateStatus(
                    kind: .active,
                    message: blockedTabs.count == 1
                        ? "Blocked \(firstURL) in \(browser.displayName)."
                        : "Blocked \(blockedTabs.count) tabs in \(browser.displayName)."
                )
            } catch {
                if let automationError = error as? MacBrowserAutomationError,
                    automationError.isTransient
                {
                    NSLog("Mac website blocking deferred for \(bundleIdentifier): \(automationError.localizedDescription)")
                    return
                }

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

        private func isBlockedAsMacApp(_ bundleIdentifier: String) -> Bool {
            guard let activeMode,
                FocusShieldSupport.isMacFocusAppBlockingEnabled
            else {
                return false
            }

            return FocusShieldSupport.loadMacBlockedApps().contains { app in
                app.bundleIdentifier == bundleIdentifier
                    && app.enabledModes.contains(activeMode)
            }
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
#endif
