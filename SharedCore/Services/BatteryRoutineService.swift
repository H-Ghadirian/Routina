import Foundation
import SwiftData

enum BatteryRoutinePreferences {
    static let monitoringEnabledDefaultsKey = "appSettingBatteryRoutineMonitoringEnabled"
    static let thresholdPercentDefaultsKey = "appSettingBatteryRoutineThresholdPercent"
    static let didChangeNotification = Notification.Name("BatteryRoutinePreferences.didChange")
    static let defaultMonitoringEnabled = false
    static let defaultThresholdPercent = 20
    static let minimumThresholdPercent = 5
    static let maximumThresholdPercent = 95

    static var isMonitoringEnabled: Bool {
        guard SharedDefaults.app.object(forKey: monitoringEnabledDefaultsKey) != nil else {
            return defaultMonitoringEnabled
        }
        return SharedDefaults.app.bool(forKey: monitoringEnabledDefaultsKey)
    }

    static var thresholdPercent: Int {
        clampedThresholdPercent(
            SharedDefaults.app.object(forKey: thresholdPercentDefaultsKey) as? Int
                ?? defaultThresholdPercent
        )
    }

    static func clampedThresholdPercent(_ value: Int) -> Int {
        min(max(value, minimumThresholdPercent), maximumThresholdPercent)
    }

    static func notifyChanged() {
        AppSettingsPersistenceMirror.schedule()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}

enum BatteryRoutineDeviceKind: String, CaseIterable, Sendable {
    case mac
    case iPhone
    case iPad
    case appleWatch

    static func isManagedRoutineID(_ id: UUID) -> Bool {
        allCases.contains { $0.routineID == id }
    }

    var routineID: UUID {
        switch self {
        case .mac:
            return UUID(uuidString: "BA77E001-0000-4000-8000-000000000001")!
        case .iPhone:
            return UUID(uuidString: "BA77E001-0000-4000-8000-000000000002")!
        case .iPad:
            return UUID(uuidString: "BA77E001-0000-4000-8000-000000000003")!
        case .appleWatch:
            return UUID(uuidString: "BA77E001-0000-4000-8000-000000000004")!
        }
    }

    var defaultRoutineName: String {
        switch self {
        case .mac:
            return "Charge Mac"
        case .iPhone:
            return "Charge iPhone"
        case .iPad:
            return "Charge iPad"
        case .appleWatch:
            return "Charge Apple Watch"
        }
    }

    var defaultNotes: String {
        "Routina updates this routine when this device battery is below the configured threshold. Pause the routine to disable battery prompts for this device."
    }
}

struct BatteryDeviceSnapshot: Equatable, Sendable {
    var kind: BatteryRoutineDeviceKind
    var levelPercent: Int
    var isCharging: Bool
    var capturedAt: Date
}

enum BatteryRoutineService {
    @MainActor
    static func reconcile(
        snapshot: BatteryDeviceSnapshot,
        in context: ModelContext,
        monitoringEnabled: Bool = BatteryRoutinePreferences.isMonitoringEnabled,
        thresholdPercent: Int = BatteryRoutinePreferences.thresholdPercent
    ) {
        guard monitoringEnabled else {
            removeManagedRoutines(in: context)
            return
        }

        let threshold = BatteryRoutinePreferences.clampedThresholdPercent(thresholdPercent)
        let isLow = !snapshot.isCharging && snapshot.levelPercent <= threshold
        let result = task(for: snapshot.kind, in: context, createdAt: snapshot.capturedAt)
        let task = result.task
        var didChange = result.didInsert

        guard !task.isArchived(referenceDate: snapshot.capturedAt, calendar: .current) else {
            if didChange {
                saveAndNotify(context)
            }
            return
        }

        if isLow {
            guard !isDismissedCurrentLowBatteryEpisode(task, at: snapshot.capturedAt) else {
                if didChange {
                    saveAndNotify(context)
                }
                return
            }
            didChange = applyLowBatteryState(to: task, at: snapshot.capturedAt) || didChange
        } else {
            didChange = clearLowBatteryState(from: task) || didChange
            didChange = clearLowBatteryDismissal(from: task) || didChange
        }

        if didChange {
            saveAndNotify(context)
        }
    }

    static func dismissCompletedLowBatteryPrompt(
        for task: RoutineTask,
        at date: Date
    ) -> Bool {
        guard BatteryRoutineDeviceKind.isManagedRoutineID(task.id) else { return false }
        var didChange = clearLowBatteryState(from: task)
        if task.lastDone == nil {
            task.lastDone = date
            didChange = true
        }
        return didChange
    }

    @MainActor
    static func removeManagedRoutines(in context: ModelContext) {
        do {
            let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
            let managedIDs = Set(BatteryRoutineDeviceKind.allCases.map(\.routineID))
            let managedTasks = tasks.filter { managedIDs.contains($0.id) }
            guard !managedTasks.isEmpty else { return }
            let managedTaskIDs = Set(managedTasks.map(\.id))

            RoutineTask.removeRelationships(
                targeting: managedTaskIDs,
                from: tasks
            )
            for task in managedTasks {
                context.delete(task)
            }
            try deleteRelatedRows(forTaskIDs: managedTaskIDs, in: context)
            saveAndNotify(context)
        } catch {
            NSLog("Failed to remove battery routines: \(error.localizedDescription)")
        }
    }

    @MainActor
    private static func task(
        for kind: BatteryRoutineDeviceKind,
        in context: ModelContext,
        createdAt: Date
    ) -> (task: RoutineTask, didInsert: Bool) {
        if let task = existingTask(for: kind, in: context) {
            return (task, false)
        }

        let task = RoutineTask(
            id: kind.routineID,
            name: kind.defaultRoutineName,
            emoji: "🔋",
            notes: kind.defaultNotes,
            priority: .none,
            importance: .level2,
            urgency: .level2,
            scheduleMode: .softInterval,
            interval: 30,
            recurrenceRule: .interval(days: 30),
            scheduleAnchor: createdAt,
            color: .none,
            createdAt: createdAt
        )
        context.insert(task)
        return (task, true)
    }

    @MainActor
    private static func existingTask(
        for kind: BatteryRoutineDeviceKind,
        in context: ModelContext
    ) -> RoutineTask? {
        let routineID = kind.routineID
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == routineID
            }
        )
        return try? context.fetch(descriptor).first
    }

    @MainActor
    private static func deleteRelatedRows(
        forTaskIDs taskIDs: Set<UUID>,
        in context: ModelContext
    ) throws {
        guard !taskIDs.isEmpty else { return }

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        for log in logs where taskIDs.contains(log.taskID) {
            context.delete(log)
        }

        let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
        for session in focusSessions
            where !session.isUnassigned && taskIDs.contains(session.taskID) {
            context.delete(session)
        }

        let attachments = try context.fetch(FetchDescriptor<RoutineAttachment>())
        for attachment in attachments where taskIDs.contains(attachment.taskID) {
            context.delete(attachment)
        }
    }

    private static func applyLowBatteryState(
        to task: RoutineTask,
        at date: Date
    ) -> Bool {
        var didChange = false
        if task.priority != .urgent {
            task.priority = .urgent
            didChange = true
        }
        if task.importance != .level4 {
            task.importance = .level4
            didChange = true
        }
        if task.urgency != .level4 {
            task.urgency = .level4
            didChange = true
        }
        if task.color != .red {
            task.color = .red
            didChange = true
        }
        if task.pinnedAt == nil {
            task.pinnedAt = date
            didChange = true
        }
        if task.lastDone != nil {
            task.lastDone = nil
            didChange = true
        }
        return didChange
    }

    private static func clearLowBatteryState(from task: RoutineTask) -> Bool {
        var didChange = false
        if task.priority == .urgent {
            task.priority = .none
            didChange = true
        }
        if task.importance == .level4 {
            task.importance = .level2
            didChange = true
        }
        if task.urgency == .level4 {
            task.urgency = .level2
            didChange = true
        }
        if task.color == .red {
            task.color = .none
            didChange = true
        }
        if task.pinnedAt != nil {
            task.pinnedAt = nil
            didChange = true
        }
        return didChange
    }

    private static func clearLowBatteryDismissal(from task: RoutineTask) -> Bool {
        guard task.lastDone != nil else { return false }
        task.lastDone = nil
        return true
    }

    private static func isDismissedCurrentLowBatteryEpisode(
        _ task: RoutineTask,
        at date: Date
    ) -> Bool {
        guard !hasLowBatteryState(task),
              let lastDone = task.lastDone else {
            return false
        }
        return Calendar.current.isDate(lastDone, inSameDayAs: date)
    }

    private static func hasLowBatteryState(_ task: RoutineTask) -> Bool {
        task.priority == .urgent
            || task.importance == .level4
            || task.urgency == .level4
            || task.color == .red
            || task.pinnedAt != nil
    }

    @MainActor
    private static func saveAndNotify(_ context: ModelContext) {
        do {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            NSLog("Battery routine update failed: \(error.localizedDescription)")
        }
    }
}
