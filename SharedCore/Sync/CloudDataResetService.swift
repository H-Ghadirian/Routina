import Foundation
import SwiftData
import UserNotifications

enum CloudDataResetService {
    @MainActor
    static func resetAllUserData(
        cloudKitContainerIdentifier: String,
        modelContext: ModelContext
    ) async throws {
        _ = cloudKitContainerIdentifier
        try wipeLocalData(in: modelContext)
        clearLocalNotifications()
    }

    @MainActor
    private static func wipeLocalData(in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks {
            context.delete(task)
        }

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        for log in logs {
            context.delete(log)
        }

        let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
        for session in focusSessions {
            context.delete(session)
        }

        let sleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
        for session in sleepSessions {
            context.delete(session)
        }

        let placeCheckIns = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        for session in placeCheckIns {
            context.delete(session)
        }

        let attachments = try context.fetch(FetchDescriptor<RoutineAttachment>())
        for att in attachments {
            context.delete(att)
        }

        let deviceActionLogs = try context.fetch(FetchDescriptor<RoutinaDeviceActionLog>())
        for log in deviceActionLogs {
            context.delete(log)
        }

        let deviceSessions = try context.fetch(FetchDescriptor<RoutinaDeviceSession>())
        for session in deviceSessions {
            context.delete(session)
        }

        try context.save()
    }

    private static func clearLocalNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
