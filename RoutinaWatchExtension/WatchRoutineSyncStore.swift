import Foundation
import WatchConnectivity
import WatchKit

@MainActor
final class WatchRoutineSyncStore: NSObject, ObservableObject, WCSessionDelegate {
    private struct ConnectivityState: Sendable {
        let isCompanionAppInstalled: Bool
        let isPhoneReachable: Bool
    }

    struct WatchRoutine: Identifiable, Equatable, Sendable, Codable {
        let id: UUID
        let name: String
        let emoji: String
        let intervalDays: Int
        let isOneOffTask: Bool
        let isChecklistDriven: Bool
        let isChecklistCompletionRoutine: Bool
        let steps: [String]
        var checklistItemCount: Int
        var completedChecklistItemCount: Int
        var nextPendingChecklistItemTitle: String?
        var dueDate: Date?
        var dueChecklistItemCount: Int
        var nextDueChecklistItemTitle: String?
        var lastDone: Date?
        var completedStepCount: Int

        var isInProgress: Bool {
            !steps.isEmpty && completedStepCount > 0 && completedStepCount < steps.count
        }

        var isCompletedOneOff: Bool {
            isOneOffTask && lastDone != nil && !isInProgress
        }

        var nextStepTitle: String? {
            guard !steps.isEmpty, completedStepCount < steps.count else { return nil }
            return steps[completedStepCount]
        }

        func daysUntilDue(from now: Date) -> Int {
            if isOneOffTask {
                return isCompletedOneOff ? Int.max : 0
            }
            let calendar = Calendar.current
            let dueDate = dueDate ?? {
                guard let lastDone else { return now }
                return calendar.date(byAdding: .day, value: max(intervalDays, 1), to: lastDone) ?? now
            }()
            let startNow = calendar.startOfDay(for: now)
            let startDue = calendar.startOfDay(for: dueDate)
            return calendar.dateComponents([.day], from: startNow, to: startDue).day ?? 0
        }

        func isDoneToday(referenceDate: Date = Date()) -> Bool {
            guard let lastDone else { return false }
            return Calendar.current.isDate(lastDone, inSameDayAs: referenceDate)
        }

        func canMarkDone(referenceDate: Date = Date()) -> Bool {
            if isOneOffTask {
                return !isCompletedOneOff
            }
            if isChecklistDriven {
                return dueChecklistItemCount > 0
            }
            if isChecklistCompletionRoutine {
                return false
            }
            return !(isDoneToday(referenceDate: referenceDate) && !isInProgress)
        }

        func advancedLocally(at completionDate: Date) -> WatchRoutine {
            if isChecklistDriven {
                return WatchRoutine(
                    id: id,
                    name: name,
                    emoji: emoji,
                    intervalDays: intervalDays,
                    isOneOffTask: isOneOffTask,
                    isChecklistDriven: true,
                    isChecklistCompletionRoutine: false,
                    steps: steps,
                    checklistItemCount: checklistItemCount,
                    completedChecklistItemCount: completedChecklistItemCount,
                    nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
                    dueDate: dueDate,
                    dueChecklistItemCount: 0,
                    nextDueChecklistItemTitle: nextDueChecklistItemTitle,
                    lastDone: completionDate,
                    completedStepCount: completedStepCount
                )
            }

            if isChecklistCompletionRoutine {
                return self
            }

            guard !steps.isEmpty else {
                return WatchRoutine(
                    id: id,
                    name: name,
                    emoji: emoji,
                    intervalDays: intervalDays,
                    isOneOffTask: isOneOffTask,
                    isChecklistDriven: false,
                    isChecklistCompletionRoutine: false,
                    steps: steps,
                    checklistItemCount: checklistItemCount,
                    completedChecklistItemCount: completedChecklistItemCount,
                    nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
                    dueDate: dueDate,
                    dueChecklistItemCount: dueChecklistItemCount,
                    nextDueChecklistItemTitle: nextDueChecklistItemTitle,
                    lastDone: completionDate,
                    completedStepCount: 0
                )
            }

            let nextCompletedStepCount = min(completedStepCount + 1, steps.count)
            if nextCompletedStepCount < steps.count {
                return WatchRoutine(
                id: id,
                name: name,
                emoji: emoji,
                intervalDays: intervalDays,
                isOneOffTask: isOneOffTask,
                isChecklistDriven: false,
                isChecklistCompletionRoutine: false,
                steps: steps,
                checklistItemCount: checklistItemCount,
                completedChecklistItemCount: completedChecklistItemCount,
                nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
                dueDate: dueDate,
                dueChecklistItemCount: dueChecklistItemCount,
                nextDueChecklistItemTitle: nextDueChecklistItemTitle,
                lastDone: lastDone,
                completedStepCount: nextCompletedStepCount
                )
            }

            return WatchRoutine(
                id: id,
                name: name,
                emoji: emoji,
                intervalDays: intervalDays,
                isOneOffTask: isOneOffTask,
                isChecklistDriven: false,
                isChecklistCompletionRoutine: false,
                steps: steps,
                checklistItemCount: checklistItemCount,
                completedChecklistItemCount: completedChecklistItemCount,
                nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
                dueDate: dueDate,
                dueChecklistItemCount: dueChecklistItemCount,
                nextDueChecklistItemTitle: nextDueChecklistItemTitle,
                lastDone: completionDate,
                completedStepCount: 0
            )
        }
    }

    struct WatchPlace: Identifiable, Equatable, Sendable, Codable {
        let id: UUID
        let name: String
    }

    enum WatchPlaceActivity: String, Equatable, Sendable, Codable {
        case work
        case commute
        case errands
        case exercise
        case rest
        case social
        case other

        var title: String {
            switch self {
            case .work:
                return "Work"
            case .commute:
                return "Commute"
            case .errands:
                return "Errands"
            case .exercise:
                return "Exercise"
            case .rest:
                return "Rest"
            case .social:
                return "Social"
            case .other:
                return "Other"
            }
        }
    }

    struct WatchPlaceCheckIn: Identifiable, Equatable, Sendable, Codable {
        let id: UUID
        let placeID: UUID?
        let placeName: String
        let activity: WatchPlaceActivity?
        let startedAt: Date

        func elapsedSeconds(at date: Date = .now) -> TimeInterval {
            max(0, date.timeIntervalSince(startedAt))
        }
    }

    struct WatchSleepSession: Identifiable, Equatable, Sendable, Codable {
        let id: UUID
        let startedAt: Date
        let targetWakeAt: Date?
        let targetDurationMinutes: Int

        func elapsedSeconds(at date: Date = .now) -> TimeInterval {
            max(0, date.timeIntervalSince(startedAt))
        }
    }

    enum WatchFocusKind: String, Sendable, Codable {
        case task
        case sprint
        case unassigned

        var deepLinkPath: String? {
            switch self {
            case .task, .sprint:
                return rawValue
            case .unassigned:
                return nil
            }
        }

        var displayTitle: String {
            switch self {
            case .task:
                return "Focus"
            case .sprint:
                return "Sprint Focus"
            case .unassigned:
                return "Focus"
            }
        }

        var systemImage: String {
            switch self {
            case .task:
                return "timer"
            case .sprint:
                return "flag.checkered"
            case .unassigned:
                return "stopwatch"
            }
        }
    }

    private enum WatchRoutineDeepLinkURL {
        private static let productionScheme = "routina"
        private static let sandboxScheme = "routina-dev"

        static func url(path: String, targetID: UUID) -> URL {
            URL(string: "\(scheme)://\(path)/\(targetID.uuidString)")!
        }

        private static var scheme: String {
            if let configuredScheme = Bundle.main.infoDictionary?["RoutinaDeepLinkURLScheme"] as? String {
                let cleanedScheme = configuredScheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !cleanedScheme.isEmpty {
                    return cleanedScheme
                }
            }

            let bundleID = Bundle.main.bundleIdentifier?.lowercased()
            return bundleID?.contains(".dev") == true ? sandboxScheme : productionScheme
        }
    }

    struct WatchFocusSession: Identifiable, Equatable, Sendable, Codable {
        let id: UUID
        let focusKind: WatchFocusKind?
        let targetID: UUID?
        let taskID: UUID?
        let taskName: String
        let taskEmoji: String
        let startedAt: Date
        let plannedDurationSeconds: TimeInterval
        let pausedAt: Date?
        let accumulatedPausedSeconds: TimeInterval

        var resolvedFocusKind: WatchFocusKind {
            focusKind ?? .task
        }

        var deepLinkTargetID: UUID? {
            targetID ?? taskID
        }

        var deepLinkURL: URL? {
            guard let deepLinkPath = resolvedFocusKind.deepLinkPath,
                  let deepLinkTargetID else {
                return nil
            }
            return WatchRoutineDeepLinkURL.url(path: deepLinkPath, targetID: deepLinkTargetID)
        }

        var isCountUp: Bool {
            plannedDurationSeconds <= 0
        }

        var isPaused: Bool {
            pausedAt != nil
        }

        var canPause: Bool {
            resolvedFocusKind != .sprint
        }

        var endDate: Date? {
            guard plannedDurationSeconds > 0 else { return nil }
            return startedAt.addingTimeInterval(plannedDurationSeconds + max(0, accumulatedPausedSeconds))
        }

        func elapsedSeconds(at date: Date = .now) -> TimeInterval {
            let endDate = pausedAt ?? date
            return max(0, endDate.timeIntervalSince(startedAt) - max(0, accumulatedPausedSeconds))
        }

        func remainingSeconds(at date: Date = .now) -> TimeInterval {
            max(0, plannedDurationSeconds - elapsedSeconds(at: date))
        }

        func pausing(at date: Date = .now) -> WatchFocusSession {
            guard canPause, pausedAt == nil else { return self }
            return WatchFocusSession(
                id: id,
                focusKind: focusKind,
                targetID: targetID,
                taskID: taskID,
                taskName: taskName,
                taskEmoji: taskEmoji,
                startedAt: startedAt,
                plannedDurationSeconds: plannedDurationSeconds,
                pausedAt: max(date, startedAt),
                accumulatedPausedSeconds: accumulatedPausedSeconds
            )
        }

        func resuming(at date: Date = .now) -> WatchFocusSession {
            guard let pausedAt else { return self }
            let resumedAt = max(date, pausedAt)
            return WatchFocusSession(
                id: id,
                focusKind: focusKind,
                targetID: targetID,
                taskID: taskID,
                taskName: taskName,
                taskEmoji: taskEmoji,
                startedAt: startedAt,
                plannedDurationSeconds: plannedDurationSeconds,
                pausedAt: nil,
                accumulatedPausedSeconds: max(0, accumulatedPausedSeconds) + resumedAt.timeIntervalSince(pausedAt)
            )
        }
    }

    private struct FocusPayloadUpdate: Sendable {
        let wasPresent: Bool
        let focus: WatchFocusSession?
    }

    private struct PlaceCheckInPayloadUpdate: Sendable {
        let wasPresent: Bool
        let checkIn: WatchPlaceCheckIn?
    }

    private struct SleepPayloadUpdate: Sendable {
        let wasPresent: Bool
        let sleep: WatchSleepSession?
    }

    @Published private(set) var routines: [WatchRoutine] = []
    @Published private(set) var places: [WatchPlace] = []
    @Published private(set) var activePlaceCheckIn: WatchPlaceCheckIn?
    @Published private(set) var activeSleepSession: WatchSleepSession?
    @Published private(set) var activeFocusSession: WatchFocusSession?
    @Published private(set) var isCompanionAppInstalled = false
    @Published private(set) var isPhoneReachable = false

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private let cacheKey = "watch.cachedRoutines.v3"
    private let placesCacheKey = "watch.cachedPlaces.v1"
    private let placeCheckInCacheKey = "watch.cachedPlaceCheckIn.v1"
    private let sleepCacheKey = "watch.cachedSleepSession.v1"
    private let focusCacheKey = "watch.cachedFocusSession.v1"
    private let pendingRoutineKey = "watch.pendingRoutines.v3"
    private let installationIDKey = "watch.device.installationID.v1"
    private var pendingRoutineByID: [UUID: WatchRoutine] = [:]
    private var batteryRefreshTask: Task<Void, Never>?

    override init() {
        super.init()
        loadPendingRoutines()
        loadCachedRoutines()
        loadCachedPlaces()
        loadCachedPlaceCheckIn()
        loadCachedSleepSession()
        loadCachedFocusSession()
        startPeriodicBatteryRefresh()

        guard let session else { return }
        session.delegate = self
        session.activate()
        updateConnectivityState(Self.makeConnectivityState(from: session))
    }

    func requestSync() {
        guard let session else { return }
        updateConnectivityState(Self.makeConnectivityState(from: session))
        sendBatteryStatus()

        if session.activationState == .activated {
            let context = session.receivedApplicationContext
            applyPayload(context)
        }

        if session.isReachable {
            session.sendMessage(actionPayload(["requestSync": true]), replyHandler: nil)
        } else {
            session.transferUserInfo(actionPayload(["requestSync": true]))
        }
    }

    func markRoutineDone(id: UUID) {
        let completionDate = Date()
        applyPendingAdvanceToLocalRoutine(id: id, completionDate: completionDate)
        savePendingRoutines()
        saveCachedRoutines()

        guard let session else { return }

        let payload = actionPayload([
            "action": "markDone",
            "taskID": id.uuidString,
            "completedAt": completionDate.timeIntervalSince1970
        ])

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    func checkInPlace(id: UUID) {
        let checkedInAt = Date()
        if let place = places.first(where: { $0.id == id }) {
            activePlaceCheckIn = WatchPlaceCheckIn(
                id: UUID(),
                placeID: place.id,
                placeName: place.name,
                activity: nil,
                startedAt: checkedInAt
            )
            saveCachedPlaceCheckIn()
        }

        guard let session else { return }

        let payload = actionPayload([
            "action": "checkInPlace",
            "placeID": id.uuidString,
            "checkedInAt": checkedInAt.timeIntervalSince1970
        ])

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    func endPlaceCheckIn() {
        let endedAt = Date()
        activePlaceCheckIn = nil
        saveCachedPlaceCheckIn()

        guard let session else { return }

        let payload = actionPayload([
            "action": "endPlaceCheckIn",
            "endedAt": endedAt.timeIntervalSince1970
        ])

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    func startSleep() {
        let startedAt = Date()
        activeSleepSession = WatchSleepSession(
            id: UUID(),
            startedAt: startedAt,
            targetWakeAt: startedAt.addingTimeInterval(8 * 60 * 60),
            targetDurationMinutes: 8 * 60
        )
        saveCachedSleepSession()

        guard let session else { return }

        let payload = actionPayload([
            "action": "startSleep",
            "startedAt": startedAt.timeIntervalSince1970
        ])

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    func endSleep() {
        let endedAt = Date()
        activeSleepSession = nil
        saveCachedSleepSession()

        guard let session else { return }

        let payload = actionPayload([
            "action": "endSleep",
            "endedAt": endedAt.timeIntervalSince1970
        ])

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    func startFocus() {
        let startedAt = Date()
        let sessionID = UUID()
        activeFocusSession = WatchFocusSession(
            id: sessionID,
            focusKind: .unassigned,
            targetID: nil,
            taskID: nil,
            taskName: "Unassigned focus",
            taskEmoji: "🎯",
            startedAt: startedAt,
            plannedDurationSeconds: 0,
            pausedAt: nil,
            accumulatedPausedSeconds: 0
        )
        saveCachedFocusSession()

        guard let session else { return }

        let payload = actionPayload([
            "action": "startUnassignedFocus",
            "sessionID": sessionID.uuidString,
            "startedAt": startedAt.timeIntervalSince1970
        ])

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    func pauseFocus(_ focus: WatchFocusSession) {
        let pausedAt = Date()
        activeFocusSession = focus.pausing(at: pausedAt)
        saveCachedFocusSession()

        guard let session else { return }

        let payload = actionPayload([
            "action": "pauseFocus",
            "sessionID": focus.id.uuidString,
            "focusKind": focus.resolvedFocusKind.rawValue,
            "pausedAt": pausedAt.timeIntervalSince1970
        ])

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    func resumeFocus(_ focus: WatchFocusSession) {
        let resumedAt = Date()
        activeFocusSession = focus.resuming(at: resumedAt)
        saveCachedFocusSession()

        guard let session else { return }

        let payload = actionPayload([
            "action": "resumeFocus",
            "sessionID": focus.id.uuidString,
            "focusKind": focus.resolvedFocusKind.rawValue,
            "resumedAt": resumedAt.timeIntervalSince1970
        ])

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    func finishFocus(_ focus: WatchFocusSession) {
        let endedAt = Date()
        activeFocusSession = nil
        saveCachedFocusSession()

        guard let session else { return }

        let payload = actionPayload([
            "action": "finishFocus",
            "sessionID": focus.id.uuidString,
            "focusKind": focus.resolvedFocusKind.rawValue,
            "endedAt": endedAt.timeIntervalSince1970
        ])

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    func openOnPhone(_ focus: WatchFocusSession) {
        guard let url = focus.deepLinkURL else { return }

        WKExtension.shared().openSystemURL(url)

        guard let session else {
            NSLog("Watch open-on-iPhone used URL fallback only: session is unavailable")
            return
        }
        var payload = actionPayload([
            "action": "openDeepLink",
            "url": url.absoluteString,
            "focusKind": focus.resolvedFocusKind.rawValue
        ])
        payload["targetID"] = focus.deepLinkTargetID?.uuidString

        guard session.activationState == .activated else {
            NSLog("Watch open-on-iPhone skipped: session is not activated")
            return
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                NSLog("Watch open-on-iPhone message failed: \(error.localizedDescription)")
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            NSLog("WatchConnectivity (watch) activation failed: \(error.localizedDescription)")
            return
        }

        let context = session.receivedApplicationContext
        let parsed = Self.parsePayload(context)
        let hasRoutinesPayload = Self.containsRoutinesPayload(context)
        let parsedPlaces = Self.parsePlacesPayload(context)
        let hasPlacesPayload = Self.containsPlacesPayload(context)
        let placeCheckInUpdate = Self.parsePlaceCheckInPayload(context)
        let sleepUpdate = Self.parseSleepPayload(context)
        let focusUpdate = Self.parseFocusPayload(context)
        let connectivityState = Self.makeConnectivityState(from: session)
        Task { @MainActor [weak self] in
            self?.updateConnectivityState(connectivityState)
            if hasRoutinesPayload {
                self?.setRoutines(parsed)
            }
            if hasPlacesPayload {
                self?.setPlaces(parsedPlaces)
            }
            if placeCheckInUpdate.wasPresent {
                self?.setActivePlaceCheckIn(placeCheckInUpdate.checkIn)
            }
            if sleepUpdate.wasPresent {
                self?.setActiveSleepSession(sleepUpdate.sleep)
            }
            if focusUpdate.wasPresent {
                self?.setActiveFocusSession(focusUpdate.focus)
            }
            self?.sendBatteryStatus()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let parsed = Self.parsePayload(applicationContext)
        let hasRoutinesPayload = Self.containsRoutinesPayload(applicationContext)
        let parsedPlaces = Self.parsePlacesPayload(applicationContext)
        let hasPlacesPayload = Self.containsPlacesPayload(applicationContext)
        let placeCheckInUpdate = Self.parsePlaceCheckInPayload(applicationContext)
        let sleepUpdate = Self.parseSleepPayload(applicationContext)
        let focusUpdate = Self.parseFocusPayload(applicationContext)
        let connectivityState = Self.makeConnectivityState(from: session)
        Task { @MainActor [weak self] in
            self?.updateConnectivityState(connectivityState)
            if hasRoutinesPayload {
                self?.setRoutines(parsed)
            }
            if hasPlacesPayload {
                self?.setPlaces(parsedPlaces)
            }
            if placeCheckInUpdate.wasPresent {
                self?.setActivePlaceCheckIn(placeCheckInUpdate.checkIn)
            }
            if sleepUpdate.wasPresent {
                self?.setActiveSleepSession(sleepUpdate.sleep)
            }
            if focusUpdate.wasPresent {
                self?.setActiveFocusSession(focusUpdate.focus)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let parsed = Self.parsePayload(message)
        let parsedPlaces = Self.parsePlacesPayload(message)
        let placeCheckInUpdate = Self.parsePlaceCheckInPayload(message)
        let sleepUpdate = Self.parseSleepPayload(message)
        let focusUpdate = Self.parseFocusPayload(message)
        guard !parsed.isEmpty || !parsedPlaces.isEmpty || placeCheckInUpdate.wasPresent || sleepUpdate.wasPresent || focusUpdate.wasPresent else { return }
        let connectivityState = Self.makeConnectivityState(from: session)
        Task { @MainActor [weak self] in
            self?.updateConnectivityState(connectivityState)
            if !parsed.isEmpty {
                self?.setRoutines(parsed)
            }
            if !parsedPlaces.isEmpty {
                self?.setPlaces(parsedPlaces)
            }
            if placeCheckInUpdate.wasPresent {
                self?.setActivePlaceCheckIn(placeCheckInUpdate.checkIn)
            }
            if sleepUpdate.wasPresent {
                self?.setActiveSleepSession(sleepUpdate.sleep)
            }
            if focusUpdate.wasPresent {
                self?.setActiveFocusSession(focusUpdate.focus)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let parsed = Self.parsePayload(userInfo)
        let parsedPlaces = Self.parsePlacesPayload(userInfo)
        let placeCheckInUpdate = Self.parsePlaceCheckInPayload(userInfo)
        let sleepUpdate = Self.parseSleepPayload(userInfo)
        let focusUpdate = Self.parseFocusPayload(userInfo)
        guard !parsed.isEmpty || !parsedPlaces.isEmpty || placeCheckInUpdate.wasPresent || sleepUpdate.wasPresent || focusUpdate.wasPresent else { return }
        let connectivityState = Self.makeConnectivityState(from: session)
        Task { @MainActor [weak self] in
            self?.updateConnectivityState(connectivityState)
            if !parsed.isEmpty {
                self?.setRoutines(parsed)
            }
            if !parsedPlaces.isEmpty {
                self?.setPlaces(parsedPlaces)
            }
            if placeCheckInUpdate.wasPresent {
                self?.setActivePlaceCheckIn(placeCheckInUpdate.checkIn)
            }
            if sleepUpdate.wasPresent {
                self?.setActiveSleepSession(sleepUpdate.sleep)
            }
            if focusUpdate.wasPresent {
                self?.setActiveFocusSession(focusUpdate.focus)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let connectivityState = Self.makeConnectivityState(from: session)
        Task { @MainActor [weak self] in
            self?.updateConnectivityState(connectivityState)
            guard connectivityState.isPhoneReachable else { return }
            self?.requestSync()
        }
    }

    private func applyPayload(_ payload: [String: Any]) {
        if Self.containsRoutinesPayload(payload) {
            setRoutines(Self.parsePayload(payload))
        }

        if Self.containsPlacesPayload(payload) {
            setPlaces(Self.parsePlacesPayload(payload))
        }

        let placeCheckInUpdate = Self.parsePlaceCheckInPayload(payload)
        if placeCheckInUpdate.wasPresent {
            setActivePlaceCheckIn(placeCheckInUpdate.checkIn)
        }

        let sleepUpdate = Self.parseSleepPayload(payload)
        if sleepUpdate.wasPresent {
            setActiveSleepSession(sleepUpdate.sleep)
        }

        let focusUpdate = Self.parseFocusPayload(payload)
        if focusUpdate.wasPresent {
            setActiveFocusSession(focusUpdate.focus)
        }
    }

    private func startPeriodicBatteryRefresh() {
        batteryRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15 * 60))
                guard !Task.isCancelled else { return }
                self?.sendBatteryStatus()
            }
        }
    }

    private func sendBatteryStatus() {
        guard let session else { return }
        guard session.activationState == .activated else { return }
        guard let payload = currentBatteryPayload() else { return }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                NSLog("Watch battery status message failed: \(error.localizedDescription)")
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func currentBatteryPayload() -> [String: Any]? {
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true

        let level = device.batteryLevel
        guard level >= 0 else { return nil }

        let state = device.batteryState
        let isCharging = state == .charging || state == .full
        return [
            "action": "batteryStatus",
            "deviceKind": "appleWatch",
            "levelPercent": Int((level * 100).rounded()),
            "isCharging": isCharging,
            "capturedAt": Date().timeIntervalSince1970,
            "sourceDevice": currentDeviceSourcePayload()
        ]
    }

    private func actionPayload(_ payload: [String: Any]) -> [String: Any] {
        var payload = payload
        payload["sourceDevice"] = currentDeviceSourcePayload()
        return payload
    }

    private func currentDeviceSourcePayload() -> [String: Any] {
        let device = WKInterfaceDevice.current()
        return [
            "installationID": watchInstallationID(),
            "displayName": device.name,
            "platform": "appleWatch",
            "modelName": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "appVersion": Self.currentAppVersion,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? ""
        ]
    }

    private func watchInstallationID() -> String {
        if let existing = UserDefaults.standard.string(forKey: installationIDKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }

        let installationID = UUID().uuidString
        UserDefaults.standard.set(installationID, forKey: installationIDKey)
        return installationID
    }

    private static var currentAppVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (.some(version), .some(build)) where !build.isEmpty:
            return "\(version) (\(build))"
        case let (.some(version), _):
            return version
        case let (_, .some(build)):
            return build
        default:
            return ""
        }
    }

    private func setRoutines(_ mapped: [WatchRoutine]) {
        let merged = mapped.map { routine in
            guard let pendingRoutine = pendingRoutineByID[routine.id] else { return routine }
            return remoteHasCaughtUp(routine, pending: pendingRoutine) ? routine : pendingRoutine
        }

        pendingRoutineByID = pendingRoutineByID.filter { routineID, pendingRoutine in
            guard let remoteRoutine = mapped.first(where: { $0.id == routineID }) else {
                return !pendingRoutine.isCompletedOneOff
            }
            return !remoteHasCaughtUp(remoteRoutine, pending: pendingRoutine)
        }

        routines = merged
            .filter { !$0.isCompletedOneOff }
            .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        savePendingRoutines()
        saveCachedRoutines()
    }

    private func setPlaces(_ mapped: [WatchPlace]) {
        places = mapped
        saveCachedPlaces()
    }

    private func setActivePlaceCheckIn(_ checkIn: WatchPlaceCheckIn?) {
        activePlaceCheckIn = checkIn
        saveCachedPlaceCheckIn()
    }

    private func setActiveSleepSession(_ sleep: WatchSleepSession?) {
        activeSleepSession = sleep
        saveCachedSleepSession()
    }

    private func setActiveFocusSession(_ focus: WatchFocusSession?) {
        activeFocusSession = focus
        saveCachedFocusSession()
    }

    private func updateConnectivityState(_ state: ConnectivityState) {
        isCompanionAppInstalled = state.isCompanionAppInstalled
        isPhoneReachable = state.isPhoneReachable
    }

    nonisolated private static func parsePayload(_ payload: [String: Any]) -> [WatchRoutine] {
        guard let rawRoutines = payload["routines"] as? [[String: Any]] else { return [] }

        return rawRoutines.compactMap { raw in
            guard
                let idString = raw["id"] as? String,
                let id = UUID(uuidString: idString)
            else {
                return nil
            }

            let name = ((raw["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let safeName = name.isEmpty ? "Unnamed task" : name
            let emoji = ((raw["emoji"] as? String) ?? "").isEmpty ? "✨" : ((raw["emoji"] as? String) ?? "✨")
            let interval = max((raw["interval"] as? Int) ?? 1, 1)
            let scheduleModeRawValue = (raw["scheduleMode"] as? String) ?? "fixedInterval"
            let isOneOffTask = scheduleModeRawValue == "oneOff"
            let isChecklistDriven = (raw["isChecklistDriven"] as? Bool) ?? false
            let isChecklistCompletionRoutine = (raw["isChecklistCompletionRoutine"] as? Bool) ?? false
            let steps = ((raw["steps"] as? [String]) ?? []).compactMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            let checklistItemCount = max((raw["checklistItemCount"] as? Int) ?? 0, 0)
            let completedChecklistItemCount = max((raw["completedChecklistItemCount"] as? Int) ?? 0, 0)
            let nextPendingChecklistItemTitle = (raw["nextPendingChecklistItemTitle"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let dueDateTimestamp = raw["dueDate"] as? TimeInterval
            let dueDate = dueDateTimestamp.map(Date.init(timeIntervalSince1970:))
            let dueChecklistItemCount = max((raw["dueChecklistItemCount"] as? Int) ?? 0, 0)
            let nextDueChecklistItemTitle = (raw["nextDueChecklistItemTitle"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lastDoneTimestamp = raw["lastDone"] as? TimeInterval
            let lastDone = lastDoneTimestamp.map(Date.init(timeIntervalSince1970:))
            let completedStepCount = max((raw["completedStepCount"] as? Int) ?? 0, 0)

            return WatchRoutine(
                id: id,
                name: safeName,
                emoji: emoji,
                intervalDays: interval,
                isOneOffTask: isOneOffTask,
                isChecklistDriven: isChecklistDriven,
                isChecklistCompletionRoutine: isChecklistCompletionRoutine,
                steps: steps,
                checklistItemCount: checklistItemCount,
                completedChecklistItemCount: min(completedChecklistItemCount, checklistItemCount),
                nextPendingChecklistItemTitle: nextPendingChecklistItemTitle?.isEmpty == true ? nil : nextPendingChecklistItemTitle,
                dueDate: dueDate,
                dueChecklistItemCount: dueChecklistItemCount,
                nextDueChecklistItemTitle: nextDueChecklistItemTitle?.isEmpty == true ? nil : nextDueChecklistItemTitle,
                lastDone: lastDone,
                completedStepCount: min(completedStepCount, steps.count)
            )
        }
    }

    nonisolated private static func parsePlacesPayload(_ payload: [String: Any]) -> [WatchPlace] {
        guard let rawPlaces = payload["places"] as? [[String: Any]] else { return [] }

        return rawPlaces.compactMap { raw in
            guard
                let idString = raw["id"] as? String,
                let id = UUID(uuidString: idString)
            else {
                return nil
            }

            let name = ((raw["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return WatchPlace(id: id, name: name.isEmpty ? "Unnamed place" : name)
        }
    }

    nonisolated private static func parsePlaceCheckInPayload(_ payload: [String: Any]) -> PlaceCheckInPayloadUpdate {
        guard let rawCheckIn = payload["placeCheckIn"] as? [String: Any] else {
            return PlaceCheckInPayloadUpdate(wasPresent: false, checkIn: nil)
        }

        guard (rawCheckIn["isActive"] as? Bool) == true else {
            return PlaceCheckInPayloadUpdate(wasPresent: true, checkIn: nil)
        }

        guard
            let sessionIDString = rawCheckIn["sessionID"] as? String,
            let sessionID = UUID(uuidString: sessionIDString),
            let startedAtTimestamp = rawCheckIn["startedAt"] as? TimeInterval
        else {
            return PlaceCheckInPayloadUpdate(wasPresent: true, checkIn: nil)
        }

        let placeName = ((rawCheckIn["placeName"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let placeID = (rawCheckIn["placeID"] as? String).flatMap(UUID.init(uuidString:))
        let activity = (rawCheckIn["activity"] as? String).flatMap(WatchPlaceActivity.init(rawValue:))

        return PlaceCheckInPayloadUpdate(
            wasPresent: true,
            checkIn: WatchPlaceCheckIn(
                id: sessionID,
                placeID: placeID,
                placeName: placeName.isEmpty ? "Current place" : placeName,
                activity: activity,
                startedAt: Date(timeIntervalSince1970: startedAtTimestamp)
            )
        )
    }

    nonisolated private static func parseSleepPayload(_ payload: [String: Any]) -> SleepPayloadUpdate {
        guard let rawSleep = payload["sleep"] as? [String: Any] else {
            return SleepPayloadUpdate(wasPresent: false, sleep: nil)
        }

        guard (rawSleep["isActive"] as? Bool) == true else {
            return SleepPayloadUpdate(wasPresent: true, sleep: nil)
        }

        guard
            let sessionIDString = rawSleep["sessionID"] as? String,
            let sessionID = UUID(uuidString: sessionIDString),
            let startedAtTimestamp = rawSleep["startedAt"] as? TimeInterval
        else {
            return SleepPayloadUpdate(wasPresent: true, sleep: nil)
        }

        let startedAt = Date(timeIntervalSince1970: startedAtTimestamp)
        let targetDurationMinutes = max((rawSleep["targetDurationMinutes"] as? Int) ?? 8 * 60, 1)
        let targetWakeAt = (rawSleep["targetWakeAt"] as? TimeInterval)
            .map(Date.init(timeIntervalSince1970:))
            ?? startedAt.addingTimeInterval(TimeInterval(targetDurationMinutes * 60))

        return SleepPayloadUpdate(
            wasPresent: true,
            sleep: WatchSleepSession(
                id: sessionID,
                startedAt: startedAt,
                targetWakeAt: targetWakeAt,
                targetDurationMinutes: targetDurationMinutes
            )
        )
    }

    nonisolated private static func parseFocusPayload(_ payload: [String: Any]) -> FocusPayloadUpdate {
        guard let rawFocus = payload["focus"] as? [String: Any] else {
            return FocusPayloadUpdate(wasPresent: false, focus: nil)
        }

        guard (rawFocus["isActive"] as? Bool) == true else {
            return FocusPayloadUpdate(wasPresent: true, focus: nil)
        }

        guard
            let sessionIDString = rawFocus["sessionID"] as? String,
            let sessionID = UUID(uuidString: sessionIDString),
            let startedAtTimestamp = rawFocus["startedAt"] as? TimeInterval
        else {
            return FocusPayloadUpdate(wasPresent: true, focus: nil)
        }

        let focusKind = WatchFocusKind(rawValue: (rawFocus["focusKind"] as? String) ?? "") ?? .task
        let taskID = (rawFocus["taskID"] as? String).flatMap(UUID.init(uuidString:))
        let targetID = ((rawFocus["targetID"] as? String) ?? (rawFocus["sprintID"] as? String))
            .flatMap(UUID.init(uuidString:))
            ?? taskID

        guard focusKind == .unassigned || targetID != nil else {
            return FocusPayloadUpdate(wasPresent: true, focus: nil)
        }

        let taskName = ((rawFocus["taskName"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let taskEmoji = ((rawFocus["taskEmoji"] as? String) ?? "").isEmpty
            ? "🎯"
            : ((rawFocus["taskEmoji"] as? String) ?? "🎯")

        return FocusPayloadUpdate(
            wasPresent: true,
            focus: WatchFocusSession(
                id: sessionID,
                focusKind: focusKind,
                targetID: targetID,
                taskID: taskID,
                taskName: taskName.isEmpty ? "Focus session" : taskName,
                taskEmoji: taskEmoji,
                startedAt: Date(timeIntervalSince1970: startedAtTimestamp),
                plannedDurationSeconds: (rawFocus["plannedDurationSeconds"] as? TimeInterval) ?? 0,
                pausedAt: (rawFocus["pausedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)),
                accumulatedPausedSeconds: max(0, (rawFocus["accumulatedPausedSeconds"] as? TimeInterval) ?? 0)
            )
        )
    }

    nonisolated private static func makeConnectivityState(from session: WCSession) -> ConnectivityState {
        ConnectivityState(
            isCompanionAppInstalled: session.isCompanionAppInstalled,
            isPhoneReachable: session.isReachable
        )
    }

    nonisolated private static func containsRoutinesPayload(_ payload: [String: Any]) -> Bool {
        payload["routines"] != nil
    }

    nonisolated private static func containsPlacesPayload(_ payload: [String: Any]) -> Bool {
        payload["places"] != nil
    }

    private func loadCachedRoutines() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        guard let decoded = try? JSONDecoder().decode([WatchRoutine].self, from: data) else { return }
        let merged = decoded.map { routine in
            pendingRoutineByID[routine.id] ?? routine
        }
        routines = merged
            .filter { !$0.isCompletedOneOff }
            .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func loadCachedPlaces() {
        guard let data = UserDefaults.standard.data(forKey: placesCacheKey) else { return }
        guard let decoded = try? JSONDecoder().decode([WatchPlace].self, from: data) else { return }
        places = decoded
    }

    private func loadCachedPlaceCheckIn() {
        guard let data = UserDefaults.standard.data(forKey: placeCheckInCacheKey) else { return }
        activePlaceCheckIn = try? JSONDecoder().decode(WatchPlaceCheckIn.self, from: data)
    }

    private func loadCachedSleepSession() {
        guard let data = UserDefaults.standard.data(forKey: sleepCacheKey) else { return }
        activeSleepSession = try? JSONDecoder().decode(WatchSleepSession.self, from: data)
    }

    private func loadCachedFocusSession() {
        guard let data = UserDefaults.standard.data(forKey: focusCacheKey) else { return }
        activeFocusSession = try? JSONDecoder().decode(WatchFocusSession.self, from: data)
    }

    private func saveCachedPlaces() {
        guard let encoded = try? JSONEncoder().encode(places) else { return }
        UserDefaults.standard.set(encoded, forKey: placesCacheKey)
    }

    private func saveCachedPlaceCheckIn() {
        guard let activePlaceCheckIn else {
            UserDefaults.standard.removeObject(forKey: placeCheckInCacheKey)
            return
        }

        guard let data = try? JSONEncoder().encode(activePlaceCheckIn) else { return }
        UserDefaults.standard.set(data, forKey: placeCheckInCacheKey)
    }

    private func saveCachedSleepSession() {
        guard let activeSleepSession else {
            UserDefaults.standard.removeObject(forKey: sleepCacheKey)
            return
        }

        guard let data = try? JSONEncoder().encode(activeSleepSession) else { return }
        UserDefaults.standard.set(data, forKey: sleepCacheKey)
    }

    private func saveCachedFocusSession() {
        guard let activeFocusSession else {
            UserDefaults.standard.removeObject(forKey: focusCacheKey)
            return
        }

        guard let data = try? JSONEncoder().encode(activeFocusSession) else { return }
        UserDefaults.standard.set(data, forKey: focusCacheKey)
    }

    private func saveCachedRoutines() {
        guard let encoded = try? JSONEncoder().encode(routines) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }

    private func loadPendingRoutines() {
        guard let data = UserDefaults.standard.data(forKey: pendingRoutineKey) else { return }
        guard let decoded = try? JSONDecoder().decode([String: WatchRoutine].self, from: data) else { return }
        pendingRoutineByID = decoded.reduce(into: [:]) { partialResult, entry in
            guard let id = UUID(uuidString: entry.key) else { return }
            partialResult[id] = entry.value
        }
    }

    private func savePendingRoutines() {
        let encoded = pendingRoutineByID.reduce(into: [String: WatchRoutine]()) { partialResult, entry in
            partialResult[entry.key.uuidString] = entry.value
        }
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        UserDefaults.standard.set(data, forKey: pendingRoutineKey)
    }

    private func applyPendingAdvanceToLocalRoutine(id: UUID, completionDate: Date) {
        let updated = routines.map { routine in
            guard routine.id == id else { return routine }
            let advancedRoutine = routine.advancedLocally(at: completionDate)
            pendingRoutineByID[id] = advancedRoutine
            return advancedRoutine
        }
        routines = updated.filter { !$0.isCompletedOneOff }
    }

    private func remoteHasCaughtUp(_ remote: WatchRoutine, pending: WatchRoutine) -> Bool {
        let remoteDone = remote.lastDone ?? .distantPast
        let pendingDone = pending.lastDone ?? .distantPast

        if remoteDone > pendingDone {
            return true
        }
        if remoteDone < pendingDone {
            return false
        }

        return remote.completedStepCount >= pending.completedStepCount
    }
}
