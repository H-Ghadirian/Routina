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

        let awaySessions = try context.fetch(FetchDescriptor<AwaySession>())
        for session in awaySessions {
            context.delete(session)
        }

        let placeCheckIns = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        for session in placeCheckIns {
            context.delete(session)
        }

        let emotionLogs = try context.fetch(FetchDescriptor<EmotionLog>())
        for emotion in emotionLogs {
            context.delete(emotion)
        }

        let notes = try context.fetch(FetchDescriptor<RoutineNote>())
        for note in notes {
            context.delete(note)
        }

        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        for event in events {
            context.delete(event)
        }

        let noteAttachments = try context.fetch(FetchDescriptor<RoutineNoteAttachment>())
        for attachment in noteAttachments {
            context.delete(attachment)
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
