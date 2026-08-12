import Darwin
import Dispatch
import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// A lightweight, development-only symptom recorder for investigating a run
/// without requiring the person reproducing it to attach Instruments.
///
/// The profile intentionally records aggregate process health, app lifecycle,
/// and a closed set of high-level interaction categories. It never reads
/// SwiftData, task content, query text, account details, or network payloads.
/// Use it to locate *when* a slowdown happened and what broad action preceded
/// it; use an Instruments trace to identify the responsible call stack.
final class RoutinaPerformanceProfiler: @unchecked Sendable {
    static let shared = RoutinaPerformanceProfiler()

    static let fileName = "RoutinaPerformanceProfile.json"
    static let previousRunFileName = "RoutinaPerformanceProfile-PreviousRun.json"

    static let isEnabled = shouldEnable(
        isDebugBuild: isDebugBuild,
        isAutomatedTestMode: AppEnvironment.isAutomatedTestMode
    )

    private static let isDebugBuild: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()

    private static let resourceSampleInterval: TimeInterval = 1
    private static let healthCheckInterval: TimeInterval = 0.5
    private static let mainThreadHitchThreshold: TimeInterval = 0.75
    private static let flushInterval: TimeInterval = 5
    private static let maximumResourceSamples = 900
    private static let maximumHitches = 200
    private static let maximumLifecycleEvents = 80
    private static let maximumInteractionEvents = 240
    private static let interactionDeduplicationWindow: TimeInterval = 0.75
    private static let hitchInteractionContextWindow: TimeInterval = 10
    private static let maximumInteractionsPerHitch = 3

    private let stateLock = NSLock()
    private let samplingQueue = DispatchQueue(
        label: "ir.hamedgh.routina.performance-profile.sampling",
        qos: .utility
    )
    private let writingQueue = DispatchQueue(
        label: "ir.hamedgh.routina.performance-profile.writing",
        qos: .utility
    )

    private var state = State()
    private var resourceTimer: DispatchSourceTimer?
    private var healthCheckTimer: DispatchSourceTimer?
    private var terminationObserver: NSObjectProtocol?

    private init() {}

    func startIfNeeded() {
        guard Self.isEnabled else { return }

        let profileURL = Self.defaultProfileURL()
        let previousRunProfileURL = profileURL.map(Self.previousRunProfileURL(for:))
        let didStart = withStateLock { state in
            guard !state.isRunning else { return false }

            let now = Date()
            state = State(
                isRunning: true,
                sessionIdentifier: UUID().uuidString,
                startedAt: now,
                startedUptime: ProcessInfo.processInfo.systemUptime,
                profileURL: profileURL,
                previousRunProfileURL: previousRunProfileURL
            )
            state.lifecycleEvents.append(
                RoutinaPerformanceLifecycleEvent(
                    timestamp: now,
                    uptimeSeconds: state.startedUptime,
                    name: "app.launch"
                )
            )
            return true
        }

        guard didStart else { return }

        if let profileURL, let previousRunProfileURL {
            RoutinaPerformanceProfileFileStore.preserveCurrentProfileAsPreviousRun(
                currentProfileURL: profileURL,
                previousRunProfileURL: previousRunProfileURL
            )
        }

        installTerminationObserver()
        startTimers()
        recordResourceSample()
        flush()

        if let path = latestProfileURL?.path {
            NSLog("Routina performance profile recording to \(path)")
        }
    }

    func recordScenePhase(_ scenePhase: String) {
        recordLifecycleEvent("scene.\(scenePhase)")
    }

    func addMarker(_ marker: RoutinaPerformanceMarker = .manual) {
        recordLifecycleEvent("marker.\(marker.rawValue)")
    }

    /// Records only a fixed, privacy-safe interaction category. Callers cannot
    /// attach task names, query text, identifiers, or other user content.
    func recordInteraction(_ interaction: RoutinaPerformanceInteraction) {
        RoutinaCrashReporter.recordInteraction(interaction)
        guard Self.isEnabled else { return }

        let now = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        withStateLock { state in
            guard state.isRunning else { return }

            if let previous = state.interactionEvents.last,
               previous.name == interaction.rawValue,
               uptime - previous.uptimeSeconds < Self.interactionDeduplicationWindow {
                return
            }

            appendBounded(
                RoutinaPerformanceInteractionEvent(
                    timestamp: now,
                    uptimeSeconds: uptime,
                    name: interaction.rawValue
                ),
                to: &state.interactionEvents,
                maximumCount: Self.maximumInteractionEvents,
                droppedCount: &state.droppedInteractionEventCount
            )
        }
    }

    func flush() {
        guard Self.isEnabled else { return }

        writingQueue.async { [weak self] in
            guard let self, let snapshot = self.profileSnapshot() else { return }
            RoutinaPerformanceProfileWriter.write(snapshot, to: snapshot.fileURL)
        }
    }

    var latestProfileURL: URL? {
        withStateLock { state in
            state.profileURL
        }
    }

    var previousRunProfileURL: URL? {
        withStateLock { state in
            guard let profileURL = state.previousRunProfileURL,
                  FileManager.default.fileExists(atPath: profileURL.path) else {
                return nil
            }
            return profileURL
        }
    }

    static func shouldEnable(
        isDebugBuild: Bool,
        isAutomatedTestMode: Bool
    ) -> Bool {
        isDebugBuild && !isAutomatedTestMode
    }

    private func startTimers() {
        let resourceTimer = DispatchSource.makeTimerSource(queue: samplingQueue)
        resourceTimer.schedule(
            deadline: .now() + Self.resourceSampleInterval,
            repeating: Self.resourceSampleInterval,
            leeway: .milliseconds(100)
        )
        resourceTimer.setEventHandler { [weak self] in
            self?.recordResourceSample()
        }

        let healthCheckTimer = DispatchSource.makeTimerSource(queue: samplingQueue)
        healthCheckTimer.schedule(
            deadline: .now() + Self.healthCheckInterval,
            repeating: Self.healthCheckInterval,
            leeway: .milliseconds(50)
        )
        healthCheckTimer.setEventHandler { [weak self] in
            let scheduledUptime = ProcessInfo.processInfo.systemUptime
            DispatchQueue.main.async {
                self?.recordMainThreadHealthCheck(scheduledUptime: scheduledUptime)
            }
        }

        withStateLock { state in
            self.resourceTimer = resourceTimer
            self.healthCheckTimer = healthCheckTimer
        }
        resourceTimer.resume()
        healthCheckTimer.resume()
    }

    private func installTerminationObserver() {
        #if os(macOS)
        let notificationName = NSApplication.willTerminateNotification
        #elseif os(iOS)
        let notificationName = UIApplication.willTerminateNotification
        #endif

        terminationObserver = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.recordLifecycleEvent("app.will-terminate")
            self?.writeSnapshotSynchronously()
        }
    }

    private func recordResourceSample() {
        guard let resourceSnapshot = ProcessResourceSampler.snapshot() else { return }

        let shouldFlush = withStateLock { state in
            guard state.isRunning else { return false }

            let now = Date()
            let uptime = ProcessInfo.processInfo.systemUptime
            let cpuPercent: Double
            if let previousCPUSeconds = state.previousCPUSeconds,
               let previousUptime = state.previousSampleUptime,
               uptime > previousUptime {
                cpuPercent = max(
                    0,
                    (resourceSnapshot.cumulativeCPUSeconds - previousCPUSeconds)
                        / (uptime - previousUptime)
                        * 100
                )
            } else {
                cpuPercent = 0
            }

            state.previousCPUSeconds = resourceSnapshot.cumulativeCPUSeconds
            state.previousSampleUptime = uptime
            appendBounded(
                RoutinaPerformanceResourceSample(
                    timestamp: now,
                    uptimeSeconds: uptime,
                    cpuPercent: cpuPercent,
                    residentMemoryBytes: resourceSnapshot.residentMemoryBytes,
                    thermalState: ProcessInfo.processInfo.thermalState.profileDescription,
                    isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
                ),
                to: &state.resourceSamples,
                maximumCount: Self.maximumResourceSamples,
                droppedCount: &state.droppedResourceSampleCount
            )

            guard uptime - state.lastFlushUptime >= Self.flushInterval else { return false }
            state.lastFlushUptime = uptime
            return true
        }

        if shouldFlush {
            flush()
        }
    }

    private func recordMainThreadHealthCheck(scheduledUptime: TimeInterval) {
        let observedUptime = ProcessInfo.processInfo.systemUptime
        let delay = observedUptime - scheduledUptime
        guard delay >= Self.mainThreadHitchThreshold else { return }

        let shouldFlush = withStateLock { state in
            guard state.isRunning else { return false }

            appendBounded(
                RoutinaPerformanceMainThreadHitch(
                    timestamp: Date(),
                    uptimeSeconds: observedUptime,
                    delayMilliseconds: delay * 1_000,
                    precedingInteractionNames: recentInteractionNames(
                        before: observedUptime,
                        state: state
                    )
                ),
                to: &state.mainThreadHitches,
                maximumCount: Self.maximumHitches,
                droppedCount: &state.droppedMainThreadHitchCount
            )
            return true
        }

        if shouldFlush {
            flush()
        }
    }

    private func recordLifecycleEvent(_ name: String) {
        guard Self.isEnabled else { return }

        let uptime = ProcessInfo.processInfo.systemUptime
        withStateLock { state in
            guard state.isRunning else { return }
            appendBounded(
                RoutinaPerformanceLifecycleEvent(
                    timestamp: Date(),
                    uptimeSeconds: uptime,
                    name: name
                ),
                to: &state.lifecycleEvents,
                maximumCount: Self.maximumLifecycleEvents,
                droppedCount: &state.droppedLifecycleEventCount
            )
        }
        flush()
    }

    private func writeSnapshotSynchronously() {
        guard let snapshot = profileSnapshot() else { return }
        RoutinaPerformanceProfileWriter.write(snapshot, to: snapshot.fileURL)
    }

    private func profileSnapshot() -> RoutinaPerformanceProfile? {
        withStateLock { state in
            guard
                state.isRunning,
                let startedAt = state.startedAt,
                let profileURL = state.profileURL
            else {
                return nil
            }

            return RoutinaPerformanceProfile(
                schemaVersion: 2,
                sessionIdentifier: state.sessionIdentifier,
                platform: Self.platformName,
                startedAt: startedAt,
                generatedAt: Date(),
                uptimeSeconds: max(0, ProcessInfo.processInfo.systemUptime - state.startedUptime),
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown",
                buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown",
                operatingSystem: AppEnvironment.operatingSystemDescription,
                profileMode: "Debug automatic symptom recorder",
                resourceSamples: state.resourceSamples,
                mainThreadHitches: state.mainThreadHitches,
                lifecycleEvents: state.lifecycleEvents,
                interactionEvents: state.interactionEvents,
                droppedResourceSampleCount: state.droppedResourceSampleCount,
                droppedMainThreadHitchCount: state.droppedMainThreadHitchCount,
                droppedLifecycleEventCount: state.droppedLifecycleEventCount,
                droppedInteractionEventCount: state.droppedInteractionEventCount,
                fileURL: profileURL
            )
        }
    }

    private static func defaultProfileURL() -> URL? {
        do {
            let applicationSupportDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return applicationSupportDirectory
                .appendingPathComponent("RoutinaData", isDirectory: true)
                .appendingPathComponent("PerformanceProfiles", isDirectory: true)
                .appendingPathComponent(fileName)
        } catch {
            NSLog("Failed to resolve the Routina performance profile URL: \(error.localizedDescription)")
            return nil
        }
    }

    private static func previousRunProfileURL(for currentProfileURL: URL) -> URL {
        currentProfileURL
            .deletingLastPathComponent()
            .appendingPathComponent(previousRunFileName)
    }

    private static var platformName: String {
        #if os(macOS)
        "macOS"
        #elseif os(iOS)
        "iOS"
        #else
        "Unknown"
        #endif
    }

    private func withStateLock<Value>(_ operation: (inout State) -> Value) -> Value {
        stateLock.lock()
        defer { stateLock.unlock() }
        return operation(&state)
    }

    private func recentInteractionNames(
        before uptime: TimeInterval,
        state: State
    ) -> [String] {
        state.interactionEvents
            .reversed()
            .prefix(Self.maximumInteractionsPerHitch)
            .filter { uptime - $0.uptimeSeconds <= Self.hitchInteractionContextWindow }
            .reversed()
            .map(\.name)
    }
}

private struct State {
    var isRunning = false
    var sessionIdentifier = ""
    var startedAt: Date?
    var startedUptime: TimeInterval = 0
    var profileURL: URL?
    var previousRunProfileURL: URL?
    var previousCPUSeconds: TimeInterval?
    var previousSampleUptime: TimeInterval?
    var lastFlushUptime: TimeInterval = 0
    var resourceSamples: [RoutinaPerformanceResourceSample] = []
    var mainThreadHitches: [RoutinaPerformanceMainThreadHitch] = []
    var lifecycleEvents: [RoutinaPerformanceLifecycleEvent] = []
    var interactionEvents: [RoutinaPerformanceInteractionEvent] = []
    var droppedResourceSampleCount = 0
    var droppedMainThreadHitchCount = 0
    var droppedLifecycleEventCount = 0
    var droppedInteractionEventCount = 0
}

struct RoutinaPerformanceProfile: Codable {
    var schemaVersion: Int
    var sessionIdentifier: String
    var platform: String
    var startedAt: Date
    var generatedAt: Date
    var uptimeSeconds: TimeInterval
    var appVersion: String
    var buildNumber: String
    var operatingSystem: String
    var profileMode: String
    var resourceSamples: [RoutinaPerformanceResourceSample]
    var mainThreadHitches: [RoutinaPerformanceMainThreadHitch]
    var lifecycleEvents: [RoutinaPerformanceLifecycleEvent]
    var interactionEvents: [RoutinaPerformanceInteractionEvent]
    var droppedResourceSampleCount: Int
    var droppedMainThreadHitchCount: Int
    var droppedLifecycleEventCount: Int
    var droppedInteractionEventCount: Int
    /// Kept out of the serialized report because an app-container path can
    /// disclose the local account name while adding no diagnostic value.
    var fileURL: URL = URL(fileURLWithPath: "/")

    var summary: RoutinaPerformanceProfileSummary {
        RoutinaPerformanceProfileSummary(
            maximumCPUPercent: resourceSamples.map(\.cpuPercent).max() ?? 0,
            maximumResidentMemoryBytes: resourceSamples.map(\.residentMemoryBytes).max() ?? 0,
            largestMainThreadDelayMilliseconds: mainThreadHitches.map(\.delayMilliseconds).max() ?? 0,
            mainThreadHitchCount: mainThreadHitches.count
        )
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case sessionIdentifier
        case platform
        case startedAt
        case generatedAt
        case uptimeSeconds
        case appVersion
        case buildNumber
        case operatingSystem
        case profileMode
        case resourceSamples
        case mainThreadHitches
        case lifecycleEvents
        case interactionEvents
        case droppedResourceSampleCount
        case droppedMainThreadHitchCount
        case droppedLifecycleEventCount
        case droppedInteractionEventCount
    }
}

struct RoutinaPerformanceProfileSummary: Codable, Equatable {
    var maximumCPUPercent: Double
    var maximumResidentMemoryBytes: UInt64
    var largestMainThreadDelayMilliseconds: Double
    var mainThreadHitchCount: Int
}

struct RoutinaPerformanceResourceSample: Codable, Equatable {
    var timestamp: Date
    var uptimeSeconds: TimeInterval
    var cpuPercent: Double
    var residentMemoryBytes: UInt64
    var thermalState: String
    var isLowPowerModeEnabled: Bool
}

struct RoutinaPerformanceMainThreadHitch: Codable, Equatable {
    var timestamp: Date
    var uptimeSeconds: TimeInterval
    var delayMilliseconds: Double
    var precedingInteractionNames: [String]
}

struct RoutinaPerformanceLifecycleEvent: Codable, Equatable {
    var timestamp: Date
    var uptimeSeconds: TimeInterval
    var name: String
}

struct RoutinaPerformanceInteractionEvent: Codable, Equatable {
    var timestamp: Date
    var uptimeSeconds: TimeInterval
    var name: String
}

enum RoutinaPerformanceMarker: String, Sendable {
    case manual
    case reproductionEnded = "reproduction-ended"
}

/// The only user-behavior labels eligible for a shared performance profile.
/// Keep this as a closed enum: free-form values could accidentally carry user
/// content into a support artifact.
enum RoutinaPerformanceInteraction: String, CaseIterable, Sendable {
    case navigationHome = "navigation.home"
    case navigationSearch = "navigation.search"
    case navigationGoals = "navigation.goals"
    case navigationTimeline = "navigation.timeline"
    case navigationStats = "navigation.stats"
    case navigationSettings = "navigation.settings"
    case navigationMore = "navigation.more"
    case navigationTaskReview = "navigation.task-review"
    case macSidebarRoutines = "navigation.mac-sidebar.routines"
    case macSidebarBoard = "navigation.mac-sidebar.board"
    case macSidebarGoals = "navigation.mac-sidebar.goals"
    case macSidebarAdventure = "navigation.mac-sidebar.adventure"
    case macSidebarTimeline = "navigation.mac-sidebar.timeline"
    case macSidebarStats = "navigation.mac-sidebar.stats"
    case macSidebarSettings = "navigation.mac-sidebar.settings"
    case macSidebarAddTask = "navigation.mac-sidebar.add-task"
    case homeTaskListScrolled = "scroll.home-task-list"
    case searchResultsScrolled = "scroll.search-results"
    case timelineScrolled = "scroll.timeline"
    case macScrollWheel = "scroll.mac"
    case searchQueryEdited = "search.query-edited"
    case searchQueryApplied = "search.query-applied"
    case searchQueryCleared = "search.query-cleared"
    case homeFilterOpened = "filter.home.opened"
    case homeFilterChanged = "filter.home.changed"
    case homeFilterCleared = "filter.home.cleared"
    case timelineFilterOpened = "filter.timeline.opened"
    case timelineFilterChanged = "filter.timeline.changed"
    case timelineFilterCleared = "filter.timeline.cleared"
    case statsFilterOpened = "filter.stats.opened"
    case statsFilterChanged = "filter.stats.changed"
    case statsFilterCleared = "filter.stats.cleared"
    case taskListModeChanged = "home.task-list-mode.changed"
    case taskDetailOpened = "task-detail.opened"
    case taskDetailClosed = "task-detail.closed"
    case taskComposerOpened = "task-composer.opened"
    case taskComposerClosed = "task-composer.closed"
    case taskMarkedDone = "task.marked-done"
    case taskMarkedMissed = "task.marked-missed"
    case taskMarkedCanceled = "task.marked-canceled"
    case taskPaused = "task.paused"
    case taskResumed = "task.resumed"
    case taskPlanned = "task.planned"
    case newActionMenuOpened = "new-action-menu.opened"
    case newTaskRequested = "new.task.requested"
    case newGoalRequested = "new.goal.requested"
    case newEventRequested = "new.event.requested"
    case newEmotionRequested = "new.emotion.requested"
    case newNoteRequested = "new.note.requested"
    case newCheckInRequested = "new.check-in.requested"
    case newAwayRequested = "new.away.requested"
    case newSleepRequested = "new.sleep.requested"
    case manualRefreshRequested = "sync.manual-refresh.requested"
    case settingsSyncRequested = "settings.sync.requested"
    case settingsBackupExportRequested = "settings.backup-export.requested"

    static func navigationTab(named tabName: String) -> Self? {
        switch tabName {
        case "Home": .navigationHome
        case "Search": .navigationSearch
        case "Goals": .navigationGoals
        case "Timeline": .navigationTimeline
        case "Stats": .navigationStats
        case "Settings": .navigationSettings
        case "More": .navigationMore
        default: nil
        }
    }

    static func macSidebar(named modeName: String) -> Self? {
        switch modeName {
        case "Routines": .macSidebarRoutines
        case "Board": .macSidebarBoard
        case "Goals": .macSidebarGoals
        case "Adventure": .macSidebarAdventure
        case "Timeline": .macSidebarTimeline
        case "Stats": .macSidebarStats
        case "Settings": .macSidebarSettings
        case "Add Task": .macSidebarAddTask
        default: nil
        }
    }
}

enum RoutinaPerformanceProfileWriter {
    static func write(_ profile: RoutinaPerformanceProfile, to fileURL: URL) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(profile).write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Failed to write the Routina performance profile: \(error.localizedDescription)")
        }
    }
}

enum RoutinaPerformanceProfileFileStore {
    static func preserveCurrentProfileAsPreviousRun(
        currentProfileURL: URL,
        previousRunProfileURL: URL,
        fileManager: FileManager = .default
    ) {
        guard fileManager.fileExists(atPath: currentProfileURL.path) else { return }

        do {
            try fileManager.createDirectory(
                at: previousRunProfileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let currentProfileData = try Data(contentsOf: currentProfileURL)
            try currentProfileData.write(to: previousRunProfileURL, options: [.atomic])
        } catch {
            NSLog("Failed to preserve the previous Routina performance profile: \(error.localizedDescription)")
        }
    }
}

private enum ProcessResourceSampler {
    struct Snapshot {
        var cumulativeCPUSeconds: TimeInterval
        var residentMemoryBytes: UInt64
    }

    static func snapshot() -> Snapshot? {
        guard
            let memoryInfo = memoryInfo(),
            let cpuTime = cumulativeCPUSeconds()
        else {
            return nil
        }

        return Snapshot(
            cumulativeCPUSeconds: cpuTime,
            residentMemoryBytes: UInt64(memoryInfo.resident_size)
        )
    }

    private static func memoryInfo() -> mach_task_basic_info? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS ? info : nil
    }

    private static func cumulativeCPUSeconds() -> TimeInterval? {
        var info = task_thread_times_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_thread_times_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_THREAD_TIMES_INFO),
                    $0,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return seconds(for: info.user_time) + seconds(for: info.system_time)
    }

    private static func seconds(for value: time_value_t) -> TimeInterval {
        TimeInterval(value.seconds) + TimeInterval(value.microseconds) / 1_000_000
    }
}

private extension ProcessInfo.ThermalState {
    var profileDescription: String {
        switch self {
        case .nominal:
            "nominal"
        case .fair:
            "fair"
        case .serious:
            "serious"
        case .critical:
            "critical"
        @unknown default:
            "unknown"
        }
    }
}

private func appendBounded<Value>(
    _ value: Value,
    to values: inout [Value],
    maximumCount: Int,
    droppedCount: inout Int
) {
    if values.count == maximumCount {
        values.removeFirst()
        droppedCount += 1
    }
    values.append(value)
}
