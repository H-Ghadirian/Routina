import ComposableArchitecture
import Foundation
import SwiftData

enum SettingsCloudActionExecution {
    static func beginSync(
        state: inout SettingsCloudState,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cloudSyncClient: CloudSyncClient
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsCloudEditor.beginSync(state: &state) else {
            return .none
        }

        return syncNow(
            modelContext: modelContext,
            cloudSyncClient: cloudSyncClient
        )
    }

    static func beginDataReset(
        cloudContainerIdentifier: String?,
        state: inout SettingsCloudState,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsCloudEditor.prepareDataReset(
            hasCloudContainerIdentifier: cloudContainerIdentifier != nil,
            state: &state
        ),
        let cloudContainerIdentifier
        else {
            return .none
        }

        return resetCloudData(
            cloudContainerIdentifier: cloudContainerIdentifier,
            modelContext: modelContext
        )
    }

    static func syncNow(
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        cloudSyncClient: CloudSyncClient
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                let estimate = try await SettingsCloudExecution.syncNow(
                    modelContext: modelContext,
                    cloudSyncClient: cloudSyncClient
                )
                send(.cloudUsageEstimateLoaded(estimate))
                NotificationCenter.default.postRoutineDidUpdate()
                await send(
                    .cloudSyncFinished(
                        success: true,
                        message: "Sync completed."
                    )
                )
            } catch {
                await send(
                    .cloudSyncFinished(
                        success: false,
                        message: "Sync failed: \(error.localizedDescription)"
                    )
                )
            }
        }
    }

    static func resetCloudData(
        cloudContainerIdentifier: String,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                let estimate = try await SettingsCloudExecution.resetCloudData(
                    cloudContainerIdentifier: cloudContainerIdentifier,
                    modelContext: modelContext
                )
                send(.cloudUsageEstimateLoaded(estimate))
                NotificationCenter.default.postRoutineDidUpdate()
                await send(
                    .cloudDataResetFinished(
                        success: true,
                        message: "All Routina data was deleted from iCloud and this device."
                    )
                )
            } catch {
                await send(
                    .cloudDataResetFinished(
                        success: false,
                        message: SettingsFeedbackSupport.cloudDataResetErrorMessage(for: error)
                    )
                )
            }
        }
    }
}
