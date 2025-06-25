import SwiftData

enum SettingsCloudExecution {
    @MainActor
    static func syncNow(
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cloudSyncClient: CloudSyncClient
    ) async throws -> CloudUsageEstimate {
        let context = modelContext()
        if context.hasChanges {
            try context.save()
        }

        try await cloudSyncClient.pullLatestIntoLocalStore(context)
        return SettingsDataQueries.loadCloudUsageEstimate(in: context)
    }

    @MainActor
    static func resetCloudData(
        cloudContainerIdentifier: String,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) async throws -> CloudUsageEstimate {
        try await CloudDataResetService.resetAllUserData(
            cloudKitContainerIdentifier: cloudContainerIdentifier,
            modelContext: modelContext()
        )

        let refreshedContext = modelContext()
        return SettingsDataQueries.loadCloudUsageEstimate(in: refreshedContext)
    }
}
