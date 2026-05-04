import ComposableArchitecture
import Foundation
import SwiftData

enum SettingsRefreshActionExecution {
    static func refreshContext(
        reconcileNotificationsIfEnabled notificationsEnabled: Bool,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        notificationClient: NotificationClient,
        locationClient: LocationClient,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            let result = await SettingsRefreshExecution.loadContext(
                modelContext: modelContext,
                notificationClient: notificationClient,
                locationClient: locationClient
            )
            send(.systemNotificationPermissionChecked(result.systemNotificationsEnabled))
            send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
            send(.placesLoaded(result.placeSummaries))
            send(.tagsLoaded(result.tagSummaries))
            send(.fastFilterTagsLoaded(appSettingsClient.fastFilterTags()))
            send(.tagColorsLoaded(appSettingsClient.tagColors()))
            send(.relatedTagRulesLoaded(appSettingsClient.relatedTagRules()))
            send(.learnedRelatedTagRulesLoaded(
                RoutineTagRelations.learnedRules(from: result.taskTagCollections)
            ))
            send(.locationSnapshotUpdated(result.locationSnapshot))

            await SettingsRefreshExecution.reconcileNotificationsIfNeeded(
                notificationsEnabled: notificationsEnabled,
                systemNotificationsEnabled: result.systemNotificationsEnabled,
                modelContext: modelContext,
                appSettingsClient: appSettingsClient,
                notificationClient: notificationClient
            )
        }
    }
}
