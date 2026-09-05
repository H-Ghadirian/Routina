import Foundation

#if os(macOS)
    import AppKit

    @MainActor
    final class MacFocusAppBlocker: NSObject {
        static let shared = MacFocusAppBlocker()

        private var blockedBundleIdentifiers: Set<String> = []
        private var isObservingWorkspace = false
        private var enforcementTask: Task<Void, Never>?
        private var pendingForceTerminations: Set<pid_t> = []
        private var enforcementActivity: NSObjectProtocol?

        override private init() {}

        func sync(for activeMode: ProtectionBlockingMode) {
            let apps = FocusShieldSupport.loadMacBlockedApps()
                .filter { $0.enabledModes.contains(activeMode) }
            guard FocusShieldSupport.isMacFocusAppBlockingEnabled, !apps.isEmpty else {
                stop()
                return
            }

            blockedBundleIdentifiers = Set(apps.map(\.bundleIdentifier))
            beginEnforcementActivityIfNeeded()
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
            endEnforcementActivity()
        }

        private func beginEnforcementActivityIfNeeded() {
            guard enforcementActivity == nil else { return }
            enforcementActivity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated],
                reason: "Routina is enforcing app blocking during a protected mode."
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
            var seenProcessIdentifiers: Set<pid_t> = []
            for app in NSWorkspace.shared.runningApplications {
                guard seenProcessIdentifiers.insert(app.processIdentifier).inserted else { continue }
                enforce(app)
            }

            for bundleIdentifier in blockedBundleIdentifiers {
                for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
                    guard seenProcessIdentifiers.insert(app.processIdentifier).inserted else { continue }
                    enforce(app)
                }
            }
        }

        private func enforce(_ app: NSRunningApplication) {
            guard let bundleIdentifier = app.bundleIdentifier,
                blockedBundleIdentifiers.contains(bundleIdentifier),
                bundleIdentifier != Bundle.main.bundleIdentifier
            else {
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

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard let self else { return }
                self.pendingForceTerminations.remove(processIdentifier)
                guard self.blockedBundleIdentifiers.contains(bundleIdentifier),
                    let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                        .first(where: { $0.processIdentifier == processIdentifier }),
                    app.isTerminated == false
                else {
                    return
                }

                if !app.forceTerminate() {
                    NSLog("Focus app blocking could not force quit \(bundleIdentifier).")
                }
            }
        }
    }
#endif
