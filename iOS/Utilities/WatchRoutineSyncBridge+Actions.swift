import Foundation
import SwiftData
import UIKit
import UserNotifications

extension WatchRoutineSyncBridge {
    func handleIncomingAction(_ action: IncomingAction) {
        if let source = action.sourceDevice,
            let context = modelContextProvider?()
        {
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
        case let .pauseFocus(sessionID, kind, date, source):
            pauseFocus(sessionID: sessionID, kind: kind, at: date, sourceDevice: source)
        case let .resumeFocus(sessionID, kind, date, source):
            resumeFocus(sessionID: sessionID, kind: kind, at: date, sourceDevice: source)
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
                _ = try RoutineLogHistory.markDueChecklistItemsDone(
                    taskID: taskID,
                    doneAt: completedAt,
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
        guard SharedDefaults.app[.appSettingPlacesEnabled] else { return }
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
        guard SharedDefaults.app[.appSettingPlacesEnabled] else { return }
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

    private func pauseFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        at date: Date,
        sourceDevice: RoutinaDeviceActivitySource?
    ) {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()

        do {
            _ = try FocusSessionSupport.pauseFocus(
                sessionID: sessionID,
                kind: kind,
                pausedAt: date,
                context: context,
                sourceDevice: sourceDevice
            )
            pushLatestSnapshot()
        } catch {
            NSLog("Watch pause focus sync failed: \(error.localizedDescription)")
            pushLatestSnapshot()
        }
    }

    private func resumeFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        at date: Date,
        sourceDevice: RoutinaDeviceActivitySource?
    ) {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()

        do {
            _ = try FocusSessionSupport.resumeFocus(
                sessionID: sessionID,
                kind: kind,
                resumedAt: date,
                context: context,
                sourceDevice: sourceDevice
            )
            pushLatestSnapshot()
        } catch {
            NSLog("Watch resume focus sync failed: \(error.localizedDescription)")
            pushLatestSnapshot()
        }
    }

    private func openDeepLink(_ deepLink: RoutinaDeepLink) {
        if case .note = deepLink, !SharedDefaults.app[.appSettingNotesEnabled] {
            return
        }
        NSLog(
            "Watch open-on-iPhone request received: \(deepLink.url.absoluteString), appState: \(UIApplication.shared.applicationState.rawValue)"
        )
        RoutinaDeepLinkDispatcher.open(deepLink)
        guard UIApplication.shared.applicationState != .active else { return }
        scheduleBackgroundOpenNotification(for: deepLink)
    }

    private func scheduleBackgroundOpenNotification(for deepLink: RoutinaDeepLink) {
        let now = Date()
        if let lastBackgroundOpenNotification,
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
}
