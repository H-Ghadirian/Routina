import Foundation
import SwiftData
import UIKit
import UserNotifications
import WatchConnectivity

@MainActor
final class WatchRoutineSyncBridge: NSObject, WCSessionDelegate {
    private enum IncomingAction: Sendable {
        case requestSync(RoutinaDeviceActivitySource?)
        case markDone(UUID, Date, RoutinaDeviceActivitySource?)
        case checkInPlace(UUID, Date, RoutinaDeviceActivitySource?)
        case endPlaceCheckIn(Date, RoutinaDeviceActivitySource?)
        case startSleep(Date, RoutinaDeviceActivitySource?)
        case endSleep(Date, RoutinaDeviceActivitySource?)
        case startUnassignedFocus(UUID, Date, RoutinaDeviceActivitySource?)
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
    private var modelContextProvider: (@MainActor () -> ModelContext)?
    private var hasStarted = false
    private var lastBackgroundOpenNotification: (deepLink: RoutinaDeepLink, date: Date)?

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
                let referenceDate = Date()
                let tasks = try context.fetch(descriptor)
                let places = try context.fetch(FetchDescriptor<RoutinePlace>())
                let placeCheckIns = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
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
                            "dueDate": task.isOneOffTask ? referenceDate.timeIntervalSince1970 : RoutineDateMath.dueDate(for: task, referenceDate: referenceDate).timeIntervalSince1970,
                            "dueChecklistItemCount": task.dueChecklistItems(referenceDate: referenceDate).count,
                            "nextDueChecklistItemTitle": task.nextDueChecklistItem(referenceDate: referenceDate)?.title as Any
                        ]

                        if let lastDone = task.lastDone {
                            routinePayload["lastDone"] = lastDone.timeIntervalSince1970
                        }

                        return routinePayload
                    },
                    "places": Self.placesPayload(from: places, sessions: placeCheckIns),
                    "placeCheckIn": Self.placeCheckInPayload(from: placeCheckIns, referenceDate: referenceDate),
                    "sleep": Self.sleepPayload(from: sleepSessions, referenceDate: referenceDate),
                    "focus": focusPayload
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
        if let source = action.sourceDevice,
           let context = modelContextProvider?() {
            DeviceActivityRecorder.recordDeviceSession(source, in: context)
        }

        switch action {
        case .requestSync:
            pushLatestSnapshot()
        case let .markDone(taskID, date, source):
            markRoutineDone(taskID: taskID, completedAt: date, sourceDevice: source)
        case let .checkInPlace(placeID, date, source):
            checkInPlace(placeID: placeID, at: date, sourceDevice: source)
        case let .endPlaceCheckIn(date, source):
            endPlaceCheckIn(at: date, sourceDevice: source)
        case let .startSleep(date, source):
            startSleep(at: date, sourceDevice: source)
        case let .endSleep(date, source):
            endSleep(at: date, sourceDevice: source)
        case let .startUnassignedFocus(sessionID, date, source):
            startUnassignedFocus(sessionID: sessionID, at: date, sourceDevice: source)
        case let .finishFocus(sessionID, kind, date, source):
            finishFocus(sessionID: sessionID, kind: kind, at: date, sourceDevice: source)
        case let .openDeepLink(deepLink, _):
            openDeepLink(deepLink)
        case let .batteryStatus(snapshot, _):
            reconcileBatteryStatus(snapshot)
        case .ignore:
            return
        }
    }

    private func reconcileBatteryStatus(_ snapshot: BatteryDeviceSnapshot) {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()
        BatteryRoutineService.reconcile(snapshot: snapshot, in: context)
        pushLatestSnapshot()
    }

    private func markRoutineDone(
        taskID: UUID,
        completedAt: Date,
        sourceDevice: RoutinaDeviceActivitySource?
    ) {
        guard let modelContextProvider else { return }

        let context = modelContextProvider()

        do {
            let descriptor = FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.id == taskID
                }
            )

            guard let task = try context.fetch(descriptor).first else { return }
            guard !task.isArchived() else { return }
            guard !task.isCompletedOneOff, !task.isCanceledOneOff else { return }
            guard !task.isChecklistCompletionRoutine else { return }
            if task.isChecklistDriven {
                _ = try RoutineLogHistory.markDueChecklistItemsPurchased(
                    taskID: taskID,
                    purchasedAt: completedAt,
                    context: context,
                    calendar: .current,
                    sourceDevice: sourceDevice
                )
            } else {
                _ = try RoutineLogHistory.advanceTask(
                    taskID: taskID,
                    completedAt: completedAt,
                    context: context,
                    calendar: .current,
                    sourceDevice: sourceDevice
                )
            }
            NotificationCenter.default.postRoutineDidUpdate()
            pushLatestSnapshot()
        } catch {
            NSLog("Watch markDone sync failed: \(error.localizedDescription)")
        }
    }

    private func checkInPlace(
        placeID: UUID,
        at date: Date,
        sourceDevice: RoutinaDeviceActivitySource?
    ) {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()

        do {
            _ = try PlaceCheckInSupport.checkIn(
                placeID: placeID,
                date: date,
                in: context,
                sourceDevice: sourceDevice
            )
            pushLatestSnapshot()
        } catch {
            NSLog("Watch place check-in sync failed: \(error.localizedDescription)")
        }
    }

    private func endPlaceCheckIn(
        at date: Date,
        sourceDevice: RoutinaDeviceActivitySource?
    ) {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()

        do {
            _ = try PlaceCheckInSupport.endActiveSession(at: date, in: context, sourceDevice: sourceDevice)
            pushLatestSnapshot()
        } catch {
            NSLog("Watch end place check-in sync failed: \(error.localizedDescription)")
        }
    }

    private func startSleep(
        at date: Date,
        sourceDevice: RoutinaDeviceActivitySource?
    ) {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()

        do {
            _ = try SleepSessionSupport.startSleep(
                in: context,
                at: date,
                sourceDevice: sourceDevice
            )
            pushLatestSnapshot()
        } catch {
            NSLog("Watch start sleep sync failed: \(error.localizedDescription)")
        }
    }

    private func endSleep(
        at date: Date,
        sourceDevice: RoutinaDeviceActivitySource?
    ) {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()

        do {
            _ = try SleepSessionSupport.endActiveSleep(
                in: context,
                at: date,
                sourceDevice: sourceDevice
            )
            pushLatestSnapshot()
        } catch {
            NSLog("Watch end sleep sync failed: \(error.localizedDescription)")
        }
    }

    private func startUnassignedFocus(
        sessionID: UUID,
        at date: Date,
        sourceDevice: RoutinaDeviceActivitySource?
    ) {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()

        do {
            _ = try FocusSessionSupport.startUnassignedFocus(
                id: sessionID,
                startedAt: date,
                context: context,
                sourceDevice: sourceDevice
            )
            pushLatestSnapshot()
        } catch {
            NSLog("Watch start unassigned focus sync failed: \(error.localizedDescription)")
            pushLatestSnapshot()
        }
    }

    private func finishFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        at date: Date,
        sourceDevice: RoutinaDeviceActivitySource?
    ) {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()

        do {
            _ = try FocusSessionSupport.finishFocus(
                sessionID: sessionID,
                kind: kind,
                endedAt: date,
                context: context,
                sourceDevice: sourceDevice
            )
            pushLatestSnapshot()
        } catch {
            NSLog("Watch finish focus sync failed: \(error.localizedDescription)")
            pushLatestSnapshot()
        }
    }

    private func openDeepLink(_ deepLink: RoutinaDeepLink) {
        NSLog("Watch open-on-iPhone request received: \(deepLink.url.absoluteString), appState: \(UIApplication.shared.applicationState.rawValue)")
        RoutinaDeepLinkDispatcher.open(deepLink)
        guard UIApplication.shared.applicationState != .active else { return }
        scheduleBackgroundOpenNotification(for: deepLink)
    }

    private func scheduleBackgroundOpenNotification(for deepLink: RoutinaDeepLink) {
        let now = Date()
        if
            let lastBackgroundOpenNotification,
            lastBackgroundOpenNotification.deepLink == deepLink,
            now.timeIntervalSince(lastBackgroundOpenNotification.date) < 5
        {
            return
        }
        lastBackgroundOpenNotification = (deepLink, now)

        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard Self.canPresentOpenOnPhoneNotification(authorizationStatus: settings.authorizationStatus) else {
                NSLog("Watch open-on-iPhone notification skipped: notifications are not authorized")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = Self.openOnPhoneNotificationTitle(for: deepLink)
            content.body = "Tap to open the running timer in Routina."
            content.sound = .default
            content.userInfo = deepLink.notificationUserInfo
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0

            let request = UNNotificationRequest(
                identifier: Self.openOnPhoneNotificationIdentifier(for: deepLink),
                content: content,
                trigger: nil
            )

            do {
                try await center.add(request)
                NSLog("Watch open-on-iPhone notification scheduled: \(deepLink.url.absoluteString)")
            } catch {
                NSLog("Watch open-on-iPhone notification failed: \(error.localizedDescription)")
            }
        }
    }

    nonisolated private static func parseIncomingAction(_ payload: [String: Any]) -> IncomingAction {
        let sourceDevice = RoutinaDeviceActivitySource(payload: payload["sourceDevice"] as? [String: Any])

        if
            let action = payload["action"] as? String,
            action == "markDone",
            let taskIDString = payload["taskID"] as? String,
            let taskID = UUID(uuidString: taskIDString)
        {
            let timestamp = (payload["completedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .markDone(taskID, timestamp, sourceDevice)
        }

        if
            let action = payload["action"] as? String,
            action == "checkInPlace",
            let placeIDString = payload["placeID"] as? String,
            let placeID = UUID(uuidString: placeIDString)
        {
            let timestamp = (payload["checkedInAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .checkInPlace(placeID, timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "endPlaceCheckIn" {
            let timestamp = (payload["endedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .endPlaceCheckIn(timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "startSleep" {
            let timestamp = (payload["startedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .startSleep(timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "endSleep" {
            let timestamp = (payload["endedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .endSleep(timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "startUnassignedFocus" {
            let sessionID = (payload["sessionID"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
            let timestamp = (payload["startedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .startUnassignedFocus(sessionID, timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "finishFocus" {
            let sessionID = (payload["sessionID"] as? String).flatMap(UUID.init(uuidString:))
            let kind = (payload["focusKind"] as? String).flatMap(FocusSessionKind.init(rawValue:))
            let timestamp = (payload["endedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .finishFocus(sessionID, kind, timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "openDeepLink" {
            if
                let rawURL = payload["url"] as? String,
                let url = URL(string: rawURL),
                let deepLink = RoutinaDeepLink(url: url)
            {
                return .openDeepLink(deepLink, sourceDevice)
            }

            let kind = (payload["focusKind"] as? String) ?? "task"
            let rawTargetID = (payload["targetID"] as? String) ?? (payload["taskID"] as? String)
            guard let rawTargetID, let targetID = UUID(uuidString: rawTargetID) else {
                return .ignore
            }

            if kind == "sprint" {
                return .openDeepLink(.sprint(targetID), sourceDevice)
            }

            return .openDeepLink(.task(targetID), sourceDevice)
        }

        if
            let action = payload["action"] as? String,
            action == "batteryStatus",
            let kindRawValue = payload["deviceKind"] as? String,
            let kind = BatteryRoutineDeviceKind(rawValue: kindRawValue),
            let levelPercent = payload["levelPercent"] as? Int,
            let isCharging = payload["isCharging"] as? Bool
        {
            let capturedAt = (payload["capturedAt"] as? TimeInterval)
                .map(Date.init(timeIntervalSince1970:))
                ?? Date()
            return .batteryStatus(
                BatteryDeviceSnapshot(
                    kind: kind,
                    levelPercent: levelPercent,
                    isCharging: isCharging,
                    capturedAt: capturedAt
                ),
                sourceDevice
            )
        }

        if let requestSync = payload["requestSync"] as? Bool, requestSync {
            return .requestSync(sourceDevice)
        }

        return .ignore
    }

    nonisolated private static func canPresentOpenOnPhoneNotification(
        authorizationStatus: UNAuthorizationStatus
    ) -> Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    nonisolated private static func openOnPhoneNotificationIdentifier(for deepLink: RoutinaDeepLink) -> String {
        switch deepLink {
        case let .task(taskID):
            return "watch-open-task-\(taskID.uuidString)"
        case let .goal(goalID):
            return "watch-open-goal-\(goalID.uuidString)"
        case let .note(noteID):
            return "watch-open-note-\(noteID.uuidString)"
        case let .sprint(sprintID):
            return "watch-open-sprint-\(sprintID.uuidString)"
        }
    }

    nonisolated private static func openOnPhoneNotificationTitle(for deepLink: RoutinaDeepLink) -> String {
        switch deepLink {
        case .task:
            return "Open task timer on iPhone"
        case .goal:
            return "Open goal on iPhone"
        case .note:
            return "Open note on iPhone"
        case .sprint:
            return "Open sprint timer on iPhone"
        }
    }

    @MainActor
    private static func placesPayload(
        from places: [RoutinePlace],
        sessions: [PlaceCheckInSession]
    ) -> [[String: Any]] {
        PlaceCheckInSupport.suggestedPlaces(
            places: places,
            sessions: sessions,
            limit: 8
        )
        .map { place in
            [
                "id": place.id.uuidString,
                "name": place.displayName
            ]
        }
    }

    private static func placeCheckInPayload(
        from sessions: [PlaceCheckInSession],
        referenceDate: Date
    ) -> [String: Any] {
        guard let active = sessions
            .filter({ $0.endedAt == nil })
            .sorted(by: { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
            .first,
            let startedAt = active.startedAt
        else {
            return ["isActive": false]
        }

        var payload: [String: Any] = [
            "isActive": true,
            "sessionID": active.id.uuidString,
            "placeName": active.displayPlaceName,
            "startedAt": startedAt.timeIntervalSince1970,
            "lastUpdated": referenceDate.timeIntervalSince1970
        ]
        payload["placeID"] = active.placeID?.uuidString
        payload["activity"] = active.activity?.rawValue
        return payload
    }

    private static func sleepPayload(
        from sessions: [SleepSession],
        referenceDate: Date
    ) -> [String: Any] {
        guard let active = sessions
            .filter({ $0.endedAt == nil })
            .sorted(by: { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
            .first,
            let startedAt = active.startedAt
        else {
            return ["isActive": false]
        }

        var payload: [String: Any] = [
            "isActive": true,
            "sessionID": active.id.uuidString,
            "startedAt": startedAt.timeIntervalSince1970,
            "targetDurationMinutes": active.targetDurationMinutes,
            "lastUpdated": referenceDate.timeIntervalSince1970
        ]
        payload["targetWakeAt"] = active.targetWakeAt?.timeIntervalSince1970
        return payload
    }

    @MainActor
    private static func focusPayload(
        from taskFocus: FocusTimerWidgetData,
        context: ModelContext,
        referenceDate: Date
    ) throws -> [String: Any] {
        let taskPayload = taskFocusPayload(from: taskFocus)
        let sprintPayload = try sprintFocusPayload(in: context, referenceDate: referenceDate)

        switch (taskPayload, sprintPayload) {
        case let (.some(task), .some(sprint)):
            return payloadStartedAt(task) >= payloadStartedAt(sprint) ? task : sprint
        case let (.some(task), nil):
            return task
        case let (nil, .some(sprint)):
            return sprint
        case (nil, nil):
            return ["isActive": false]
        }
    }

    nonisolated private static func taskFocusPayload(from focus: FocusTimerWidgetData) -> [String: Any]? {
        guard focus.isActive, let sessionID = focus.sessionID, let startedAt = focus.startedAt else {
            return nil
        }

        var payload: [String: Any] = [
            "isActive": true,
            "sessionID": sessionID.uuidString,
            "focusKind": focus.taskID == nil ? "unassigned" : "task",
            "taskName": focus.taskName,
            "taskEmoji": focus.taskEmoji,
            "startedAt": startedAt.timeIntervalSince1970,
            "plannedDurationSeconds": focus.plannedDurationSeconds
        ]
        if let taskID = focus.taskID {
            payload["targetID"] = taskID.uuidString
            payload["taskID"] = taskID.uuidString
        }
        return payload
    }

    @MainActor
    private static func sprintFocusPayload(in context: ModelContext, referenceDate: Date) throws -> [String: Any]? {
        let sessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        guard let session = sessions
            .filter({ $0.stoppedAt == nil })
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first
        else {
            return nil
        }

        let sprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        let title = sprints
            .first { $0.id == session.sprintID }?
            .title
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = title.map { $0.isEmpty ? "Sprint focus" : $0 } ?? "Sprint focus"

        return [
            "isActive": true,
            "sessionID": session.id.uuidString,
            "focusKind": "sprint",
            "targetID": session.sprintID.uuidString,
            "sprintID": session.sprintID.uuidString,
            "taskName": displayTitle,
            "taskEmoji": "🏁",
            "startedAt": session.startedAt.timeIntervalSince1970,
            "plannedDurationSeconds": 0,
            "lastUpdated": referenceDate.timeIntervalSince1970
        ]
    }

    nonisolated private static func payloadStartedAt(_ payload: [String: Any]) -> TimeInterval {
        payload["startedAt"] as? TimeInterval ?? .leastNonzeroMagnitude
    }
}
