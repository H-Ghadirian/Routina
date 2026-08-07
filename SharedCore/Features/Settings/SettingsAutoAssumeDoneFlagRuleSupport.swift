import ComposableArchitecture
import Foundation
import SwiftData

extension SettingsFeature {
    func synchronizeAutoAssumeDoneFlagRules(affectedFlag: String) -> Effect<Action> {
        let rules = appSettingsClient.flagRules()
        return .run { @MainActor _ in
            let context = modelContext()
            let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
            var changed = false
            for task in tasks where RoutineFlag.contains(affectedFlag, in: task.flags) {
                let shouldEnable = RoutineFlagRules.enablesAutoAssumeDone(
                    flags: task.flags,
                    rules: rules
                ) && RoutineAssumedCompletion.canEnable(
                    scheduleMode: task.scheduleMode,
                    recurrenceRule: task.recurrenceRule,
                    recurrenceTimeRangeRole: task.recurrenceTimeRangeRole,
                    availabilityStartDate: task.availabilityStartDate,
                    availabilityEndDate: task.availabilityEndDate,
                    isAllDay: task.isAllDay,
                    trackingCadenceEnabled: task.trackingCadenceEnabled,
                    hasSequentialSteps: task.hasSequentialSteps,
                    hasChecklistItems: task.hasChecklistItems
                )
                guard task.autoAssumeDailyDone != shouldEnable else { continue }
                task.autoAssumeDailyDone = shouldEnable
                task.hidesAssumedDoneCalendarBlock = shouldEnable && task.hidesAssumedDoneCalendarBlock
                task.autoAssumeDoneTimeOfDay = shouldEnable
                    ? (task.autoAssumeDoneTimeOfDay ?? RoutineAssumedCompletion.defaultDoneTimeOfDay)
                    : nil
                changed = true
            }
            guard changed else { return }
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    func migrateAutoAssumeDoneTasks(to flag: String) -> Effect<Action> {
        let rules = appSettingsClient.flagRules()
        return .run { @MainActor send in
            let context = modelContext()
            let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
            var migratedCount = 0
            for task in tasks where task.autoAssumeDailyDone {
                let updatedFlags = RoutineFlag.appending(flag, to: task.flags)
                guard updatedFlags != task.flags else { continue }
                task.flags = updatedFlags
                let shouldEnable = RoutineFlagRules.enablesAutoAssumeDone(
                    flags: task.flags,
                    rules: rules
                ) && RoutineAssumedCompletion.canEnable(
                    scheduleMode: task.scheduleMode,
                    recurrenceRule: task.recurrenceRule,
                    recurrenceTimeRangeRole: task.recurrenceTimeRangeRole,
                    availabilityStartDate: task.availabilityStartDate,
                    availabilityEndDate: task.availabilityEndDate,
                    isAllDay: task.isAllDay,
                    trackingCadenceEnabled: task.trackingCadenceEnabled,
                    hasSequentialSteps: task.hasSequentialSteps,
                    hasChecklistItems: task.hasChecklistItems
                )
                task.autoAssumeDailyDone = shouldEnable
                task.hidesAssumedDoneCalendarBlock = shouldEnable && task.hidesAssumedDoneCalendarBlock
                task.autoAssumeDoneTimeOfDay = shouldEnable
                    ? (task.autoAssumeDoneTimeOfDay ?? RoutineAssumedCompletion.defaultDoneTimeOfDay)
                    : nil
                migratedCount += 1
            }
            if migratedCount > 0 {
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            }
            send(.autoAssumeDoneMigrationFinished(flag: flag, migratedCount: migratedCount))
        }
    }
}
