import Darwin
import Foundation

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
    case newFocusRequested = "new.focus.requested"
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

enum ProcessResourceSampler {
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
