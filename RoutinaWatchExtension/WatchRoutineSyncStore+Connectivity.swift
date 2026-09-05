import Foundation
import WatchConnectivity
import WatchKit

extension WatchRoutineSyncStore {
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
        guard !parsed.isEmpty || !parsedPlaces.isEmpty || placeCheckInUpdate.wasPresent || sleepUpdate.wasPresent || focusUpdate.wasPresent
        else { return }
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
        guard !parsed.isEmpty || !parsedPlaces.isEmpty || placeCheckInUpdate.wasPresent || sleepUpdate.wasPresent || focusUpdate.wasPresent
        else { return }
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

    func applyPayload(_ payload: [String: Any]) {
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

    func startPeriodicBatteryRefresh() {
        batteryRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15 * 60))
                guard !Task.isCancelled else { return }
                self?.sendBatteryStatus()
            }
        }
    }

    func sendBatteryStatus() {
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
            "sourceDevice": currentDeviceSourcePayload(),
        ]
    }

    func actionPayload(_ payload: [String: Any]) -> [String: Any] {
        var payload = payload
        payload["sourceDevice"] = currentDeviceSourcePayload()
        return payload
    }

    func sendActionPayload(_ payload: [String: Any], failureLog: String) {
        guard let session else { return }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                NSLog("\(failureLog): \(error.localizedDescription)")
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
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
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "",
        ]
    }

    private func watchInstallationID() -> String {
        if let existing = UserDefaults.standard.string(forKey: installationIDKey),
            !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
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

    nonisolated static func makeConnectivityState(from session: WCSession) -> ConnectivityState {
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

}
