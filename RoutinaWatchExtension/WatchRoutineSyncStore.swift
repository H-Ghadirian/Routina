import Foundation
import WatchConnectivity
import WatchKit

@MainActor
final class WatchRoutineSyncStore: NSObject, ObservableObject, WCSessionDelegate {
    struct ConnectivityState: Sendable {
        let isCompanionAppInstalled: Bool
        let isPhoneReachable: Bool
    }

    struct FocusPayloadUpdate: Sendable {
        let wasPresent: Bool
        let focus: WatchFocusSession?
    }

    struct PlaceCheckInPayloadUpdate: Sendable {
        let wasPresent: Bool
        let checkIn: WatchPlaceCheckIn?
    }

    struct SleepPayloadUpdate: Sendable {
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

    let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private let cacheKey = "watch.cachedRoutines.v3"
    private let placesCacheKey = "watch.cachedPlaces.v1"
    private let placeCheckInCacheKey = "watch.cachedPlaceCheckIn.v1"
    private let sleepCacheKey = "watch.cachedSleepSession.v1"
    private let focusCacheKey = "watch.cachedFocusSession.v1"
    private let locallyEndedSleepAtKey = "watch.locallyEndedSleepAt.v1"
    private let pendingRoutineKey = "watch.pendingRoutines.v3"
    let installationIDKey = "watch.device.installationID.v1"
    private var pendingRoutineByID: [UUID: WatchRoutine] = [:]
    var batteryRefreshTask: Task<Void, Never>?

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

        sendActionPayload(
            actionPayload(["requestSync": true]),
            failureLog: "Watch request sync message failed"
        )
    }

    func markRoutineDone(id: UUID) {
        let completionDate = Date()
        applyPendingAdvanceToLocalRoutine(id: id, completionDate: completionDate)
        savePendingRoutines()
        saveCachedRoutines()

        let payload = actionPayload([
            "action": "markDone",
            "taskID": id.uuidString,
            "completedAt": completionDate.timeIntervalSince1970,
        ])

        sendActionPayload(payload, failureLog: "Watch mark routine done message failed")
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

        let payload = actionPayload([
            "action": "checkInPlace",
            "placeID": id.uuidString,
            "checkedInAt": checkedInAt.timeIntervalSince1970,
        ])

        sendActionPayload(payload, failureLog: "Watch place check-in message failed")
    }

    func endPlaceCheckIn() {
        let endedAt = Date()
        activePlaceCheckIn = nil
        saveCachedPlaceCheckIn()

        let payload = actionPayload([
            "action": "endPlaceCheckIn",
            "endedAt": endedAt.timeIntervalSince1970,
        ])

        sendActionPayload(payload, failureLog: "Watch end place check-in message failed")
    }

    func startSleep() {
        let startedAt = Date()
        clearLocallyEndedSleepAt()
        activeSleepSession = WatchSleepSession(
            id: UUID(),
            startedAt: startedAt,
            targetWakeAt: startedAt.addingTimeInterval(8 * 60 * 60),
            targetDurationMinutes: 8 * 60
        )
        saveCachedSleepSession()

        let payload = actionPayload([
            "action": "startSleep",
            "startedAt": startedAt.timeIntervalSince1970,
        ])

        sendActionPayload(payload, failureLog: "Watch start sleep message failed")
    }

    func endSleep() {
        let endedAt = Date()
        setLocallyEndedSleepAt(endedAt)
        activeSleepSession = nil
        saveCachedSleepSession()

        let payload = actionPayload([
            "action": "endSleep",
            "endedAt": endedAt.timeIntervalSince1970,
        ])

        sendActionPayload(payload, failureLog: "Watch end sleep message failed")
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

        let payload = actionPayload([
            "action": "startUnassignedFocus",
            "sessionID": sessionID.uuidString,
            "startedAt": startedAt.timeIntervalSince1970,
        ])

        sendActionPayload(payload, failureLog: "Watch start focus message failed")
    }

    func pauseFocus(_ focus: WatchFocusSession) {
        let pausedAt = Date()
        activeFocusSession = focus.pausing(at: pausedAt)
        saveCachedFocusSession()

        let payload = actionPayload([
            "action": "pauseFocus",
            "sessionID": focus.id.uuidString,
            "focusKind": focus.resolvedFocusKind.rawValue,
            "pausedAt": pausedAt.timeIntervalSince1970,
        ])

        sendActionPayload(payload, failureLog: "Watch pause focus message failed")
    }

    func resumeFocus(_ focus: WatchFocusSession) {
        let resumedAt = Date()
        activeFocusSession = focus.resuming(at: resumedAt)
        saveCachedFocusSession()

        let payload = actionPayload([
            "action": "resumeFocus",
            "sessionID": focus.id.uuidString,
            "focusKind": focus.resolvedFocusKind.rawValue,
            "resumedAt": resumedAt.timeIntervalSince1970,
        ])

        sendActionPayload(payload, failureLog: "Watch resume focus message failed")
    }

    func finishFocus(_ focus: WatchFocusSession) {
        let endedAt = Date()
        activeFocusSession = nil
        saveCachedFocusSession()

        let payload = actionPayload([
            "action": "finishFocus",
            "sessionID": focus.id.uuidString,
            "focusKind": focus.resolvedFocusKind.rawValue,
            "endedAt": endedAt.timeIntervalSince1970,
        ])

        sendActionPayload(payload, failureLog: "Watch finish focus message failed")
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
            "focusKind": focus.resolvedFocusKind.rawValue,
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

    func setRoutines(_ mapped: [WatchRoutine]) {
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

        routines =
            merged
            .filter { !$0.isCompletedOneOff }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        savePendingRoutines()
        saveCachedRoutines()
    }

    func setPlaces(_ mapped: [WatchPlace]) {
        places = mapped
        saveCachedPlaces()
    }

    func setActivePlaceCheckIn(_ checkIn: WatchPlaceCheckIn?) {
        activePlaceCheckIn = checkIn
        saveCachedPlaceCheckIn()
    }

    func setActiveSleepSession(_ sleep: WatchSleepSession?) {
        if let sleep {
            if let locallyEndedAt = locallyEndedSleepAt(), sleep.startedAt <= locallyEndedAt {
                activeSleepSession = nil
                saveCachedSleepSession()
                return
            }

            clearLocallyEndedSleepAt()
        } else {
            clearLocallyEndedSleepAt()
        }

        activeSleepSession = sleep
        saveCachedSleepSession()
    }

    func setActiveFocusSession(_ focus: WatchFocusSession?) {
        activeFocusSession = focus
        saveCachedFocusSession()
    }

    func updateConnectivityState(_ state: ConnectivityState) {
        isCompanionAppInstalled = state.isCompanionAppInstalled
        isPhoneReachable = state.isPhoneReachable
    }

    private func loadCachedRoutines() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        guard let decoded = try? JSONDecoder().decode([WatchRoutine].self, from: data) else { return }
        let merged = decoded.map { routine in
            pendingRoutineByID[routine.id] ?? routine
        }
        routines =
            merged
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

    private func locallyEndedSleepAt() -> Date? {
        guard let timestamp = UserDefaults.standard.object(forKey: locallyEndedSleepAtKey) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func setLocallyEndedSleepAt(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: locallyEndedSleepAtKey)
    }

    private func clearLocallyEndedSleepAt() {
        UserDefaults.standard.removeObject(forKey: locallyEndedSleepAtKey)
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
