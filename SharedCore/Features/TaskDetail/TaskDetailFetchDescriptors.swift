import Foundation
import SwiftData

enum TaskDetailFetchDescriptors {
    static func sortedLogs(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    static func task(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }

    static func log(for logID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.id == logID
            }
        )
    }

    static func allLogs(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
    }

    static func focusSessions(for taskID: UUID) -> FetchDescriptor<FocusSession> {
        FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.taskID == taskID
            }
        )
    }

    static func attachments(for taskID: UUID) -> FetchDescriptor<RoutineAttachment> {
        FetchDescriptor<RoutineAttachment>(
            predicate: #Predicate { attachment in
                attachment.taskID == taskID
            }
        )
    }
}
