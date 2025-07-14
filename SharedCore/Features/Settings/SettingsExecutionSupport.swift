import Foundation
import SwiftData

enum SettingsExecutionSupport {
    static func hasTemporaryViewStateToReset(
        appSettingsClient: AppSettingsClient
    ) -> Bool {
        appSettingsClient.hideUnavailableRoutines()
            || appSettingsClient.temporaryViewState() != nil
    }

    static func withSecurityScopedAccess<T>(
        to url: URL,
        _ operation: () throws -> T
    ) throws -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    @MainActor
    static func rescheduleNotificationsIfNeeded(
        in context: ModelContext,
        appSettingsClient: AppSettingsClient,
        notificationClient: NotificationClient
    ) async throws {
        await notificationClient.cancelAll()

        guard appSettingsClient.notificationsEnabled() else { return }
        guard await notificationClient.systemNotificationsAuthorized() else { return }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks {
            guard NotificationCoordinator.shouldScheduleNotification(for: task) else { continue }
            await notificationClient.schedule(NotificationCoordinator.notificationPayload(for: task))
        }
    }

    @MainActor
    static func rescheduleNotificationsAfterImport(
        in context: ModelContext,
        appSettingsClient: AppSettingsClient,
        notificationClient: NotificationClient
    ) async throws {
        try await rescheduleNotificationsIfNeeded(
            in: context,
            appSettingsClient: appSettingsClient,
            notificationClient: notificationClient
        )
    }
}
