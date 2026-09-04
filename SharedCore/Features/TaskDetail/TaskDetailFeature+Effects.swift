import ComposableArchitecture
import Foundation
import SwiftData

extension TaskDetailFeature {
    func handleOnAppear(taskID: UUID) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                if let task = try context.fetch(TaskDetailFetchDescriptors.task(for: taskID)).first {
                    if task.clearStoppedOngoingStateIfNeeded(calendar: calendar) {
                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                    }
                }
                _ = try RoutineLogHistory.backfillMissingLastDoneLog(for: taskID, in: context)
                let logs = RoutineLogHistory.detailLogs(taskID: taskID, context: context)
                send(.logsLoaded(logs))
                let attachments = try context.fetch(TaskDetailFetchDescriptors.attachments(for: taskID))
                let items =
                    attachments
                    .sorted { $0.createdAt < $1.createdAt }
                    .map { AttachmentItem(id: $0.id, fileName: $0.fileName, data: $0.data) }
                send(.attachmentsLoaded(items))
                let appNotificationsEnabled = appSettingsClient.notificationsEnabled()
                let systemNotificationsAuthorized = await notificationClient.systemNotificationsAuthorized()
                send(
                    .notificationStatusLoaded(
                        appEnabled: appNotificationsEnabled,
                        systemAuthorized: systemNotificationsAuthorized
                    )
                )
            } catch {
                RoutinaLog.error("Error loading logs: \(error)")
            }
        }
    }

    func timeSpentChangeEntry(
        previousDurationMinutes: Int?,
        durationMinutes: Int?
    ) -> RoutineTaskChangeLogEntry {
        let kind: RoutineTaskChangeKind
        switch (previousDurationMinutes, durationMinutes) {
        case (nil, .some):
            kind = .timeSpentAdded
        case (.some, nil):
            kind = .timeSpentRemoved
        default:
            kind = .timeSpentChanged
        }
        return RoutineTaskChangeLogEntry(
            timestamp: now,
            kind: kind,
            previousValue: previousDurationMinutes.map(String.init),
            newValue: durationMinutes.map(String.init),
            durationMinutes: durationMinutes
        )
    }

    func appendRelationshipChangeEntries(
        to task: RoutineTask,
        previousRelationships: [RoutineTaskRelationship],
        updatedRelationships: [RoutineTaskRelationship]
    ) {
        let previousByID = Dictionary(uniqueKeysWithValues: previousRelationships.map { ($0.targetTaskID, $0) })
        let updatedByID = Dictionary(uniqueKeysWithValues: updatedRelationships.map { ($0.targetTaskID, $0) })

        for relationship in updatedRelationships where previousByID[relationship.targetTaskID] != relationship {
            task.appendChangeLogEntry(
                RoutineTaskChangeLogEntry(
                    timestamp: now,
                    kind: .linkedTaskAdded,
                    relatedTaskID: relationship.targetTaskID,
                    relationshipKind: relationship.kind
                )
            )
        }

        for relationship in previousRelationships where updatedByID[relationship.targetTaskID] == nil {
            task.appendChangeLogEntry(
                RoutineTaskChangeLogEntry(
                    timestamp: now,
                    kind: .linkedTaskRemoved,
                    relatedTaskID: relationship.targetTaskID,
                    relationshipKind: relationship.kind
                )
            )
        }
    }

}
