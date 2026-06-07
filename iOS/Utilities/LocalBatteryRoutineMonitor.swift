import Foundation
import SwiftData
import UIKit

@MainActor
final class LocalBatteryRoutineMonitor {
    static let shared = LocalBatteryRoutineMonitor()

    private var modelContextProvider: (@MainActor () -> ModelContext)?
    private var hasStarted = false
    private var refreshTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func startIfNeeded(modelContextProvider: @escaping @MainActor () -> ModelContext) {
        guard !hasStarted else { return }
        hasStarted = true
        self.modelContextProvider = modelContextProvider

        UIDevice.current.isBatteryMonitoringEnabled = true
        installObservers()
        refresh()
        startPeriodicRefresh()
    }

    private func installObservers() {
        let center = NotificationCenter.default
        let notifications: [Notification.Name] = [
            UIDevice.batteryLevelDidChangeNotification,
            UIDevice.batteryStateDidChangeNotification,
            UIApplication.didBecomeActiveNotification,
            BatteryRoutinePreferences.didChangeNotification
        ]

        observers = notifications.map { notificationName in
            center.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }
    }

    private func startPeriodicRefresh() {
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15 * 60))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    private func refresh() {
        guard let modelContextProvider else { return }
        let context = modelContextProvider()

        guard BatteryRoutinePreferences.isMonitoringEnabled else {
            BatteryRoutineService.removeManagedRoutines(in: context)
            return
        }

        guard let snapshot = currentSnapshot() else { return }
        BatteryRoutineService.reconcile(snapshot: snapshot, in: context)
    }

    private func currentSnapshot() -> BatteryDeviceSnapshot? {
#if DEBUG && targetEnvironment(simulator)
        if let snapshot = simulatorOverrideSnapshot() {
            return snapshot
        }
#endif

        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        let level = device.batteryLevel
        guard level >= 0 else { return nil }

        let kind: BatteryRoutineDeviceKind = device.userInterfaceIdiom == .pad ? .iPad : .iPhone
        let state = device.batteryState
        let isCharging = state == .charging || state == .full

        return BatteryDeviceSnapshot(
            kind: kind,
            levelPercent: Int((level * 100).rounded()),
            isCharging: isCharging,
            capturedAt: Date()
        )
    }

#if DEBUG && targetEnvironment(simulator)
    private func simulatorOverrideSnapshot() -> BatteryDeviceSnapshot? {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let rawLevel = Self.argumentValue(named: "--routina-sim-battery-level", in: arguments)
            ?? environment["ROUTINA_SIMULATED_BATTERY_LEVEL"]

        guard let rawLevel, let level = Int(rawLevel) else { return nil }

        let rawCharging = Self.argumentValue(named: "--routina-sim-battery-charging", in: arguments)
            ?? environment["ROUTINA_SIMULATED_BATTERY_CHARGING"]
        let isCharging = rawCharging.map(Self.boolValue(from:)) ?? false
        let device = UIDevice.current
        let kind: BatteryRoutineDeviceKind = device.userInterfaceIdiom == .pad ? .iPad : .iPhone

        return BatteryDeviceSnapshot(
            kind: kind,
            levelPercent: min(max(level, 0), 100),
            isCharging: isCharging,
            capturedAt: Date()
        )
    }

    private static func argumentValue(named name: String, in arguments: [String]) -> String? {
        guard
            let index = arguments.firstIndex(of: name),
            arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func boolValue(from rawValue: String) -> Bool {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
        }
    }
#endif
}
