import Foundation
import SwiftData

enum SettingsRoutineDataImportStoreResetter {
    @MainActor
    static func deleteExistingData(in context: ModelContext) throws {
        let existingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        for log in existingLogs {
            context.delete(log)
        }

        let existingSleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
        for session in existingSleepSessions {
            context.delete(session)
        }

        let existingPlaceCheckIns = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        for session in existingPlaceCheckIns {
            context.delete(session)
        }

        let existingEmotionLogs = try context.fetch(FetchDescriptor<EmotionLog>())
        for emotion in existingEmotionLogs {
            context.delete(emotion)
        }

        let existingNotes = try context.fetch(FetchDescriptor<RoutineNote>())
        for note in existingNotes {
            context.delete(note)
        }

        let existingNoteAttachments = try context.fetch(FetchDescriptor<RoutineNoteAttachment>())
        for attachment in existingNoteAttachments {
            context.delete(attachment)
        }

        let existingAttachments = try context.fetch(FetchDescriptor<RoutineAttachment>())
        for attachment in existingAttachments {
            context.delete(attachment)
        }

        let existingDeviceActionLogs = try context.fetch(FetchDescriptor<RoutinaDeviceActionLog>())
        for log in existingDeviceActionLogs {
            context.delete(log)
        }

        let existingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in existingTasks {
            context.delete(task)
        }

        let existingGoals = try context.fetch(FetchDescriptor<RoutineGoal>())
        for goal in existingGoals {
            context.delete(goal)
        }

        let existingPlaces = try context.fetch(FetchDescriptor<RoutinePlace>())
        for place in existingPlaces {
            context.delete(place)
        }
    }
}
