import ComposableArchitecture
import Foundation
import SwiftData

extension SettingsFeature {
    func synchronizeAutoAssumeDoneFlagRules(affectedFlag: String) -> Effect<Action> {
        let rules = appSettingsClient.flagRules()
        let appSettingsClient = self.appSettingsClient
        let notificationClient = self.notificationClient
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
                    cadenceEnabled: task.cadenceEnabled,
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
            try await SettingsExecutionSupport.rescheduleNotificationsIfNeeded(
                in: context,
                appSettingsClient: appSettingsClient,
                notificationClient: notificationClient
            )
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

}
