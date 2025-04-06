import Foundation
import WatchConnectivity

@MainActor
final class WatchRoutineSyncStore: NSObject, ObservableObject, WCSessionDelegate {
    struct WatchRoutine: Identifiable, Equatable, Sendable {
        let id: UUID
        let name: String
        let emoji: String
        let intervalDays: Int
        let lastDone: Date?

        func daysUntilDue(from now: Date) -> Int {
            guard let lastDone else { return 0 }
            let calendar = Calendar.current
            let dueDate = calendar.date(byAdding: .day, value: max(intervalDays, 1), to: lastDone) ?? now
            let startNow = calendar.startOfDay(for: now)
            let startDue = calendar.startOfDay(for: dueDate)
            return calendar.dateComponents([.day], from: startNow, to: startDue).day ?? 0
        }
    }

    @Published private(set) var routines: [WatchRoutine] = []

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    override init() {
        super.init()

        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func requestSync() {
        print("Hamed requesting sync...")
        guard let session else { return }

        if session.activationState == .activated {
            applyPayload(session.receivedApplicationContext)
        }

        if session.isReachable {
            print("Hamed is reachable!")
            session.sendMessage(["requestSync": true], replyHandler: nil)
        } else {
            print("Hamed is not reachable!")
            session.transferUserInfo(["requestSync": true])
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            print("Hamed error: \(error.localizedDescription)")
            NSLog("WatchConnectivity (watch) activation failed: \(error.localizedDescription)")
            return
        }

        let parsed = Self.parsePayload(session.receivedApplicationContext)
        Task { @MainActor [weak self] in
            self?.setRoutines(parsed)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let parsed = Self.parsePayload(applicationContext)
        Task { @MainActor [weak self] in
            self?.setRoutines(parsed)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let parsed = Self.parsePayload(message)
        guard !parsed.isEmpty else { return }
        Task { @MainActor [weak self] in
            self?.setRoutines(parsed)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let parsed = Self.parsePayload(userInfo)
        guard !parsed.isEmpty else { return }
        Task { @MainActor [weak self] in
            self?.setRoutines(parsed)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor [weak self] in
            self?.requestSync()
        }
    }

    private func applyPayload(_ payload: [String: Any]) {
        setRoutines(Self.parsePayload(payload))
    }

    private func setRoutines(_ mapped: [WatchRoutine]) {
        print("Hamed setRoutines")
        routines = mapped.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func parsePayload(_ payload: [String: Any]) -> [WatchRoutine] {
        payload.forEach { (key: String, value: Any) in
            print("Hamed parsePayload key: \(key) value: \(value)")
        }
        print("Hamed parsePayload")
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
}
