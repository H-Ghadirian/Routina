import Foundation

#if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
import FirebaseCore
import FirebaseCrashlytics
#endif

/// Configures production crash reporting when the matching Firebase plist is
/// present in the app bundle. Missing configuration deliberately leaves crash
/// reporting disabled so local builds and automated tests remain usable.
enum RoutinaCrashReporter {
    static let interactionDeduplicationWindow: TimeInterval = 0.75

    private static let state = State()

    static func configureIfAvailable() {
        guard !AppEnvironment.isAutomatedTestMode else { return }

        #if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        guard FirebaseApp.app() == nil else {
            state.markConfigured()
            return
        }

        guard let configurationPath = Bundle.main.path(
            forResource: "GoogleService-Info",
            ofType: "plist"
        ) else {
            NSLog("Routina Crashlytics disabled: GoogleService-Info.plist is not configured")
            return
        }

        guard let options = FirebaseOptions(contentsOfFile: configurationPath) else {
            NSLog("Routina Crashlytics disabled: GoogleService-Info.plist is invalid")
            return
        }

        FirebaseApp.configure(options: options)

        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(platformName, forKey: "routina_platform")
        crashlytics.setCustomValue(
            AppEnvironment.isDevelopmentAppVariant ? "development" : "production",
            forKey: "routina_variant"
        )
        state.markConfigured()
        crashlytics.log("routina.crash-reporting.ready")
        scheduleTestCrashIfRequested()
        #endif
    }

    /// Records only the closed interaction enum. No overload accepts free-form
    /// strings, task data, search text, record identifiers, or account details.
    static func recordInteraction(_ interaction: RoutinaPerformanceInteraction) {
        #if canImport(FirebaseCore) && canImport(FirebaseCrashlytics)
        let uptime = ProcessInfo.processInfo.systemUptime
        guard state.shouldRecord(
            interactionName: interaction.rawValue,
            uptime: uptime,
            deduplicationWindow: interactionDeduplicationWindow
        ) else { return }

        Crashlytics.crashlytics().log("routina.interaction.\(interaction.rawValue)")
        #endif
    }

    static func shouldRecordInteraction(
        previousName: String?,
        previousUptime: TimeInterval?,
        interactionName: String,
        uptime: TimeInterval,
        deduplicationWindow: TimeInterval = interactionDeduplicationWindow
    ) -> Bool {
        guard let previousName, let previousUptime else { return true }
        guard previousName == interactionName else { return true }
        return uptime - previousUptime >= deduplicationWindow
    }

    private static var platformName: String {
        #if os(macOS)
        "macOS"
        #elseif os(iOS)
        "iOS"
        #else
        "Apple"
        #endif
    }

    private static func scheduleTestCrashIfRequested() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["ROUTINA_CRASHLYTICS_TEST_CRASH"] == "1" else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            fatalError("Routina requested a Debug Crashlytics verification crash")
        }
        #endif
    }

    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var isConfigured = false
        private var previousInteractionName: String?
        private var previousInteractionUptime: TimeInterval?

        func markConfigured() {
            lock.lock()
            isConfigured = true
            lock.unlock()
        }

        func shouldRecord(
            interactionName: String,
            uptime: TimeInterval,
            deduplicationWindow: TimeInterval
        ) -> Bool {
            lock.lock()
            defer { lock.unlock() }

            guard isConfigured else { return false }
            guard RoutinaCrashReporter.shouldRecordInteraction(
                previousName: previousInteractionName,
                previousUptime: previousInteractionUptime,
                interactionName: interactionName,
                uptime: uptime,
                deduplicationWindow: deduplicationWindow
            ) else { return false }

            previousInteractionName = interactionName
            previousInteractionUptime = uptime
            return true
        }
    }
}
