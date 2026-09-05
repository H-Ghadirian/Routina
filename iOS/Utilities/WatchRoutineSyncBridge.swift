import Foundation
import SwiftData
import UIKit
import UserNotifications
import WatchConnectivity

@MainActor
final class WatchRoutineSyncBridge: NSObject, WCSessionDelegate {
    enum IncomingAction: Sendable {
        case requestSync(RoutinaDeviceActivitySource?)
        case markDone(UUID, Date, RoutinaDeviceActivitySource?)
        case checkInPlace(UUID, Date, RoutinaDeviceActivitySource?)
        case endPlaceCheckIn(Date, RoutinaDeviceActivitySource?)
        case startSleep(Date, RoutinaDeviceActivitySource?)
        case endSleep(Date, RoutinaDeviceActivitySource?)
        case startUnassignedFocus(UUID, Date, RoutinaDeviceActivitySource?)
        case pauseFocus(UUID?, FocusSessionKind?, Date, RoutinaDeviceActivitySource?)
        case resumeFocus(UUID?, FocusSessionKind?, Date, RoutinaDeviceActivitySource?)
        case finishFocus(UUID?, FocusSessionKind?, Date, RoutinaDeviceActivitySource?)
        case openDeepLink(RoutinaDeepLink, RoutinaDeviceActivitySource?)
        case batteryStatus(BatteryDeviceSnapshot, RoutinaDeviceActivitySource?)
        case ignore

        var sourceDevice: RoutinaDeviceActivitySource? {
            switch self {
            case let .requestSync(source),
                let .markDone(_, _, source),
                let .checkInPlace(_, _, source),
                let .endPlaceCheckIn(_, source),
                let .startSleep(_, source),
                let .endSleep(_, source),
                let .startUnassignedFocus(_, _, source),
                let .pauseFocus(_, _, _, source),
                let .resumeFocus(_, _, _, source),
                let .finishFocus(_, _, _, source),
                let .openDeepLink(_, source),
                let .batteryStatus(_, source):
                return source
            case .ignore:
                return nil
            }
        }
    }

    static let shared = WatchRoutineSyncBridge()

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    var modelContextProvider: (@MainActor () -> ModelContext)?
    private var hasStarted = false
    var lastBackgroundOpenNotification: (deepLink: RoutinaDeepLink, date: Date)?

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

    func pushLatestSnapshot() {
        guard let session else { return }
        guard session.activationState == .activated else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let modelContextProvider = self.modelContextProvider else { return }

            let context = modelContextProvider()
            let descriptor = FetchDescriptor<RoutineTask>()

            do {
                let referenceDate = Date()
                let tasks = try context.fetch(descriptor)
                let isPlacesEnabled = SharedDefaults.app[.appSettingPlacesEnabled]
                let places = isPlacesEnabled ? try context.fetch(FetchDescriptor<RoutinePlace>()) : []
                let placeCheckIns = isPlacesEnabled ? try context.fetch(FetchDescriptor<PlaceCheckInSession>()) : []
                let sleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
                let sessions = try context.fetch(FetchDescriptor<FocusSession>())
                let focus = FocusTimerWidgetDataComputer.compute(
                    tasks: tasks,
                    sessions: sessions,
                    referenceDate: referenceDate
                )
                let focusPayload = try Self.focusPayload(
                    from: focus,
                    context: context,
                    referenceDate: referenceDate
                )
                let payload: [String: Any] = [
                    "routines": tasks.compactMap { task -> [String: Any]? in
                        guard !task.isArchived(), !task.isCompletedOneOff, !task.isCanceledOneOff else { return nil }
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
                            "dueDate": task.isOneOffTask
                                ? referenceDate.timeIntervalSince1970
                                : RoutineDateMath.dueDate(for: task, referenceDate: referenceDate).timeIntervalSince1970,
                            "dueChecklistItemCount": task.dueChecklistItems(referenceDate: referenceDate).count,
                            "nextDueChecklistItemTitle": task.nextDueChecklistItem(referenceDate: referenceDate)?.title as Any,
                        ]

                        if let lastDone = task.lastDone {
                            routinePayload["lastDone"] = lastDone.timeIntervalSince1970
                        }

                        return routinePayload
                    },
                    "places": Self.placesPayload(from: places, sessions: placeCheckIns),
                    "placeCheckIn": Self.placeCheckInPayload(from: placeCheckIns, referenceDate: referenceDate),
                    "sleep": Self.sleepPayload(from: sleepSessions, referenceDate: referenceDate),
                    "focus": focusPayload,
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

}
