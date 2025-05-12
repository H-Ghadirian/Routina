import Foundation
import SwiftData
import UIKit
import WatchConnectivity

@MainActor
final class WatchRoutineSyncBridge: NSObject, WCSessionDelegate {
    private enum IncomingAction: Sendable {
        case requestSync
        case markDone(UUID, Date)
        case ignore
    }

    static let shared = WatchRoutineSyncBridge()

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private var modelContextProvider: (@MainActor () -> ModelContext)?
    private var hasStarted = false

    private override init() {
        super.init()
    }

    @MainActor
    func startIfNeeded(modelContextProvider: @escaping @MainActor () -> ModelContext) {
        guard !hasStarted else { return }

        hasStarted = true
        self.modelContextProvider = modelContextProvider

        guard let session else { return }

        session.delegate = self
        session.activate()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRoutineDidUpdate),
            name: .routineDidUpdate,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        pushLatestSnapshot()
    }

    @objc private func handleRoutineDidUpdate() {
        pushLatestSnapshot()
    }

    @objc private func handleDidBecomeActive() {
        pushLatestSnapshot()
    }

    private func pushLatestSnapshot() {
        guard let session else { return }
        guard session.activationState == .activated else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let modelContextProvider = self.modelContextProvider else { return }

            let context = modelContextProvider()
            let descriptor = FetchDescriptor<RoutineTask>()

            do {
                let tasks = try context.fetch(descriptor)
                let payload: [String: Any] = [
                    "routines": tasks.compactMap { task -> [String: Any]? in
                        guard !task.isPaused, !task.isCompletedOneOff, !task.isCanceledOneOff else { return nil }
                        var routinePayload: [String: Any] = [
                            "id": task.id.uuidString,
                            "name": (task.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                            "emoji": task.emoji ?? "",
                            "interval": Int(task.interval),
                            "scheduleMode": task.scheduleMode.rawValue,
                            "isChecklistDriven": task.isChecklistDriven,
                            "isChecklistCompletionRoutine": task.isChecklistCompletionRoutine,
                            "steps": task.steps.map(\.title),
                            "completedStepCount": task.completedSteps,
                            "checklistItemCount": task.totalChecklistItemCount,
                            "completedChecklistItemCount": task.completedChecklistItemCount,
                            "nextPendingChecklistItemTitle": task.nextPendingChecklistItemTitle as Any,
                            "dueDate": task.isOneOffTask ? Date().timeIntervalSince1970 : RoutineDateMath.dueDate(for: task, referenceDate: Date()).timeIntervalSince1970,
                            "dueChecklistItemCount": task.dueChecklistItems(referenceDate: Date()).count,
                            "nextDueChecklistItemTitle": task.nextDueChecklistItem(referenceDate: Date())?.title as Any
                        ]

                        if let lastDone = task.lastDone {
                            routinePayload["lastDone"] = lastDone.timeIntervalSince1970
                        }

                        return routinePayload
                    }
                ]

                try session.updateApplicationContext(payload)
                _ = session.transferUserInfo(payload)
                if session.isReachable {
                    session.sendMessage(payload, replyHandler: nil)
                }
            } catch {
                NSLog("Watch sync push failed: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            if let error {
                NSLog("WatchConnectivity activation failed: \(error.localizedDescription)")
                return
            }

            self.pushLatestSnapshot()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.pushLatestSnapshot()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.pushLatestSnapshot()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let action = Self.parseIncomingAction(message)
        Task { @MainActor in
            self.handleIncomingAction(action)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let action = Self.parseIncomingAction(message)
        Task { @MainActor in
            self.handleIncomingAction(action)
        }
        replyHandler(["acknowledged": true])
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let action = Self.parseIncomingAction(userInfo)
        Task { @MainActor in
            self.handleIncomingAction(action)
        }
    }

    private func handleIncomingAction(_ action: IncomingAction) {
        switch action {
        case .requestSync:
            pushLatestSnapshot()
        case let .markDone(taskID, date):
            markRoutineDone(taskID: taskID, completedAt: date)
        case .ignore:
            return
        }
    }

    private func markRoutineDone(taskID: UUID, completedAt: Date) {
        guard let modelContextProvider else { return }

        let context = modelContextProvider()

        do {
            let descriptor = FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.id == taskID
                }
            )

            guard let task = try context.fetch(descriptor).first else { return }
            guard !task.isPaused else { return }
            guard !task.isCompletedOneOff, !task.isCanceledOneOff else { return }
            guard !task.isChecklistCompletionRoutine else { return }
            if task.isChecklistDriven {
                _ = try RoutineLogHistory.markDueChecklistItemsPurchased(
                    taskID: taskID,
                    purchasedAt: completedAt,
                    context: context,
                    calendar: .current
                )
            } else {
                _ = try RoutineLogHistory.advanceTask(
                    taskID: taskID,
                    completedAt: completedAt,
                    context: context,
                    calendar: .current
                )
            }
            NotificationCenter.default.postRoutineDidUpdate()
            pushLatestSnapshot()
        } catch {
            NSLog("Watch markDone sync failed: \(error.localizedDescription)")
        }
    }

    nonisolated private static func parseIncomingAction(_ payload: [String: Any]) -> IncomingAction {
        if
            let action = payload["action"] as? String,
            action == "markDone",
            let taskIDString = payload["taskID"] as? String,
            let taskID = UUID(uuidString: taskIDString)
        {
            let timestamp = (payload["completedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .markDone(taskID, timestamp)
        }

        if let requestSync = payload["requestSync"] as? Bool, requestSync {
            return .requestSync
        }

        return .ignore
    }
}
