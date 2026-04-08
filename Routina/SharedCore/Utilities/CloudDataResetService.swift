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

        let attachments = try context.fetch(FetchDescriptor<RoutineAttachment>())
        for att in attachments {
            context.delete(att)
        }

        try context.save()
    }

    private static func clearLocalNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
