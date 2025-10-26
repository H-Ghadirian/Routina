import Foundation
import WatchConnectivity

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
        var lastDone: Date?

        func daysUntilDue(from now: Date) -> Int {
            guard let lastDone else { return 0 }
            let calendar = Calendar.current
            let dueDate = calendar.date(byAdding: .day, value: max(intervalDays, 1), to: lastDone) ?? now
            let startNow = calendar.startOfDay(for: now)
            let startDue = calendar.startOfDay(for: dueDate)
            return calendar.dateComponents([.day], from: startNow, to: startDue).day ?? 0
        }

        func isDoneToday(referenceDate: Date = Date()) -> Bool {
            guard let lastDone else { return false }
            return Calendar.current.isDate(lastDone, inSameDayAs: referenceDate)
        }
    }

    @Published private(set) var routines: [WatchRoutine] = []
    @Published private(set) var isCompanionAppInstalled = false
    @Published private(set) var isPhoneReachable = false

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private let cacheKey = "watch.cachedRoutines.v1"
    private let pendingDoneKey = "watch.pendingDone.v1"
    private var pendingDoneByRoutineID: [UUID: Date] = [:]

    override init() {
        super.init()
        loadPendingDone()
        loadCachedRoutines()

        guard let session else { return }
        session.delegate = self
        session.activate()
        updateConnectivityState(Self.makeConnectivityState(from: session))
    }

    func requestSync() {
        guard let session else { return }
        updateConnectivityState(Self.makeConnectivityState(from: session))

        if session.activationState == .activated {
            let context = session.receivedApplicationContext
            if Self.containsRoutinesPayload(context) {
                applyPayload(context)
            }
        }

        if session.isReachable {
            session.sendMessage(["requestSync": true], replyHandler: nil)
        } else {
            session.transferUserInfo(["requestSync": true])
        }
    }

    func markRoutineDone(id: UUID) {
        let completionDate = Date()
        pendingDoneByRoutineID[id] = completionDate

        applyPendingDoneToLocalRoutine(id: id, completionDate: completionDate)
        savePendingDone()
        saveCachedRoutines()

        guard let session else { return }

        let payload: [String: Any] = [
            "action": "markDone",
            "taskID": id.uuidString,
            "completedAt": completionDate.timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
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
        let connectivityState = Self.makeConnectivityState(from: session)
        Task { @MainActor [weak self] in
            self?.updateConnectivityState(connectivityState)
            if hasRoutinesPayload {
                self?.setRoutines(parsed)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let parsed = Self.parsePayload(applicationContext)
        let hasRoutinesPayload = Self.containsRoutinesPayload(applicationContext)
        let connectivityState = Self.makeConnectivityState(from: session)
        Task { @MainActor [weak self] in
            self?.updateConnectivityState(connectivityState)
            if hasRoutinesPayload {
                self?.setRoutines(parsed)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let parsed = Self.parsePayload(message)
        guard !parsed.isEmpty else { return }
        let connectivityState = Self.makeConnectivityState(from: session)
        Task { @MainActor [weak self] in
            self?.updateConnectivityState(connectivityState)
            self?.setRoutines(parsed)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let parsed = Self.parsePayload(userInfo)
        guard !parsed.isEmpty else { return }
        let connectivityState = Self.makeConnectivityState(from: session)
        Task { @MainActor [weak self] in
            self?.updateConnectivityState(connectivityState)
            self?.setRoutines(parsed)
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
        setRoutines(Self.parsePayload(payload))
    }

    private func setRoutines(_ mapped: [WatchRoutine]) {
        let remoteDoneByID = mapped.reduce(into: [UUID: Date]()) { partialResult, routine in
            if let lastDone = routine.lastDone {
                partialResult[routine.id] = lastDone
            }
        }

        let merged = mapped.map { routine in
            guard let pendingDate = pendingDoneByRoutineID[routine.id] else { return routine }
            let remoteDate = routine.lastDone ?? .distantPast
            let finalDate = max(remoteDate, pendingDate)
            return WatchRoutine(
                id: routine.id,
                name: routine.name,
                emoji: routine.emoji,
                intervalDays: routine.intervalDays,
                lastDone: finalDate
            )
        }

        pendingDoneByRoutineID = pendingDoneByRoutineID.filter { routineID, pendingDate in
            guard let remoteDate = remoteDoneByID[routineID] else { return true }
            return remoteDate < pendingDate
        }

        routines = merged.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        savePendingDone()
        saveCachedRoutines()
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
            let lastDoneTimestamp = raw["lastDone"] as? TimeInterval
            let lastDone = lastDoneTimestamp.map(Date.init(timeIntervalSince1970:))

            return WatchRoutine(
                id: id,
                name: safeName,
                emoji: emoji,
                intervalDays: interval,
                lastDone: lastDone
            )
        }
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

    private func loadCachedRoutines() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        guard let decoded = try? JSONDecoder().decode([WatchRoutine].self, from: data) else { return }
        let merged = decoded.map { routine in
            guard let pendingDate = pendingDoneByRoutineID[routine.id] else { return routine }
            let currentDate = routine.lastDone ?? .distantPast
            let finalDate = max(currentDate, pendingDate)
            return WatchRoutine(
                id: routine.id,
                name: routine.name,
                emoji: routine.emoji,
                intervalDays: routine.intervalDays,
                lastDone: finalDate
            )
        }
        routines = merged.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func saveCachedRoutines() {
        guard let encoded = try? JSONEncoder().encode(routines) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }

    private func loadPendingDone() {
        guard let data = UserDefaults.standard.data(forKey: pendingDoneKey) else { return }
        guard let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else { return }
        pendingDoneByRoutineID = decoded.reduce(into: [:]) { partialResult, entry in
            guard let id = UUID(uuidString: entry.key) else { return }
            partialResult[id] = Date(timeIntervalSince1970: entry.value)
        }
    }

    private func savePendingDone() {
        let encoded = pendingDoneByRoutineID.reduce(into: [String: TimeInterval]()) { partialResult, entry in
            partialResult[entry.key.uuidString] = entry.value.timeIntervalSince1970
        }
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        UserDefaults.standard.set(data, forKey: pendingDoneKey)
    }

    private func applyPendingDoneToLocalRoutine(id: UUID, completionDate: Date) {
        let updated = routines.map { routine in
            guard routine.id == id else { return routine }
            return WatchRoutine(
                id: routine.id,
                name: routine.name,
                emoji: routine.emoji,
                intervalDays: routine.intervalDays,
                lastDone: completionDate
            )
        }
        routines = updated
    }
}
