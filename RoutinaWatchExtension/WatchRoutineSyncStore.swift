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

    @Published private(set) var routines: [WatchRoutine] = []
    @Published private(set) var isCompanionAppInstalled = false
    @Published private(set) var isPhoneReachable = false

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private let cacheKey = "watch.cachedRoutines.v3"
    private let pendingRoutineKey = "watch.pendingRoutines.v3"
    private var pendingRoutineByID: [UUID: WatchRoutine] = [:]

    override init() {
        super.init()
        loadPendingRoutines()
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
        applyPendingAdvanceToLocalRoutine(id: id, completionDate: completionDate)
        savePendingRoutines()
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
            pendingRoutineByID[routine.id] ?? routine
        }
        routines = merged
            .filter { !$0.isCompletedOneOff }
            .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
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
