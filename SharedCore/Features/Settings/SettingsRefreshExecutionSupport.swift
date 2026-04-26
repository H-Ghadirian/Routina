import SwiftData

struct SettingsRefreshExecutionResult {
    var systemNotificationsEnabled: Bool
    var cloudUsageEstimate: CloudUsageEstimate
    var placeSummaries: [RoutinePlaceSummary]
    var tagSummaries: [RoutineTagSummary]
    var taskTagCollections: [[String]]
    var locationSnapshot: LocationSnapshot
}

enum SettingsRefreshExecution {
    @MainActor
    static func loadContext(
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        notificationClient: NotificationClient,
        locationClient: LocationClient
    ) async -> SettingsRefreshExecutionResult {
        let context = modelContext()
        let systemNotificationsEnabled = await notificationClient.systemNotificationsAuthorized()
        let cloudUsageEstimate = SettingsDataQueries.loadCloudUsageEstimate(in: context)
        let placeSummaries = (try? SettingsDataQueries.fetchPlaceSummaries(in: context)) ?? []
        let tagSummaries = (try? SettingsDataQueries.fetchTagSummaries(in: context)) ?? []
        let taskTagCollections = (try? SettingsDataQueries.fetchTaskTagCollections(in: context)) ?? []
        let locationSnapshot = await locationClient.snapshot(false)

        return SettingsRefreshExecutionResult(
            systemNotificationsEnabled: systemNotificationsEnabled,
            cloudUsageEstimate: cloudUsageEstimate,
            placeSummaries: placeSummaries,
            tagSummaries: tagSummaries,
            taskTagCollections: taskTagCollections,
            locationSnapshot: locationSnapshot
        )
    }

    @MainActor
    static func loadTagSummaries(
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> [RoutineTagSummary] {
        (try? SettingsDataQueries.fetchTagSummaries(in: modelContext())) ?? []
    }

    @MainActor
    static func loadTaskTagCollections(
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> [[String]] {
        (try? SettingsDataQueries.fetchTaskTagCollections(in: modelContext())) ?? []
    }

    @MainActor
    static func reconcileNotificationsIfNeeded(
        notificationsEnabled: Bool,
        systemNotificationsEnabled: Bool,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: AppSettingsClient,
        notificationClient: NotificationClient
    ) async {
        await SettingsNotificationsExecution.reconcileEnabledState(
            notificationsEnabled: notificationsEnabled,
            systemNotificationsEnabled: systemNotificationsEnabled,
            modelContext: modelContext,
            appSettingsClient: appSettingsClient,
            notificationClient: notificationClient
        )
    }
}
