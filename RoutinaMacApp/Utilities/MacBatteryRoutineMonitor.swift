import AppKit
import Foundation
import IOKit.ps
import SwiftData

@MainActor
final class MacBatteryRoutineMonitor {
    static let shared = MacBatteryRoutineMonitor()

    private var modelContextProvider: (@MainActor () -> ModelContext)?
    private var hasStarted = false
    private var refreshTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func startIfNeeded(modelContextProvider: @escaping @MainActor () -> ModelContext) {
        guard !hasStarted else { return }
        hasStarted = true
        self.modelContextProvider = modelContextProvider

        installObservers()
        refresh()
        startPeriodicRefresh()
    }

    private func installObservers() {
        let center = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            },
            center.addObserver(
                forName: BatteryRoutinePreferences.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        ]
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
            BatteryRoutineService.deactivateManagedRoutines(in: context)
            return
        }

        guard let snapshot = MacBatteryPowerSourceReader.currentSnapshot() else { return }
        BatteryRoutineService.reconcile(snapshot: snapshot, in: context)
    }
}

private enum MacBatteryPowerSourceReader {
    static func currentSnapshot() -> BatteryDeviceSnapshot? {
#if DEBUG
        if let snapshot = debugOverrideSnapshot() {
            return snapshot
        }
#endif

        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)
                    .takeUnretainedValue() as? [String: Any],
                (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int,
                let maximumCapacity = description[kIOPSMaxCapacityKey] as? Int,
                maximumCapacity > 0
            else {
                continue
            }

            let state = description[kIOPSPowerSourceStateKey] as? String
            let isCharging = (description[kIOPSIsChargingKey] as? Bool) == true
                || state == kIOPSACPowerValue
            let level = Double(currentCapacity) / Double(maximumCapacity)

            return BatteryDeviceSnapshot(
                kind: .mac,
                levelPercent: Int((level * 100).rounded()),
                isCharging: isCharging,
                capturedAt: Date()
            )
        }

        return nil
    }

#if DEBUG
    private static func debugOverrideSnapshot() -> BatteryDeviceSnapshot? {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let rawLevel = argumentValue(named: "--routina-sim-battery-level", in: arguments)
            ?? environment["ROUTINA_SIMULATED_BATTERY_LEVEL"]

        guard let rawLevel, let level = Int(rawLevel) else { return nil }

        let rawCharging = argumentValue(named: "--routina-sim-battery-charging", in: arguments)
            ?? environment["ROUTINA_SIMULATED_BATTERY_CHARGING"]
        let isCharging = rawCharging.map(boolValue(from:)) ?? false

        return BatteryDeviceSnapshot(
            kind: .mac,
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
