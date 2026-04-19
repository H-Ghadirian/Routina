import ComposableArchitecture
import Foundation
import SwiftData

enum SettingsRoutineDataTransferActionExecution {
    static func beginExport(
        state: inout SettingsDataTransferState,
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsRoutineDataTransferEditor.begin(.export, state: &state) else {
            return .none
        }

        return exportData(
            routineDataTransferClient: routineDataTransferClient,
            modelContext: modelContext
        )
    }

    static func beginImport(
        state: inout SettingsDataTransferState,
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: @escaping @Sendable () -> AppSettingsClient,
        notificationClient: @escaping @Sendable () -> NotificationClient
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsRoutineDataTransferEditor.begin(.import, state: &state) else {
            return .none
        }

        return importData(
            routineDataTransferClient: routineDataTransferClient,
            modelContext: modelContext,
            appSettingsClient: appSettingsClient,
            notificationClient: notificationClient
        )
    }

    static func exportData(
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                guard let result = try await SettingsRoutineDataTransferExecution.exportData(
                    routineDataTransferClient: routineDataTransferClient,
                    modelContext: modelContext
                ) else {
                    await send(
                        .routineDataTransferFinished(
                            success: false,
                            message: "Save canceled."
                        )
                    )
                    return
                }

                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: "Saved to \(result.destinationFileName)."
                    )
                )
            } catch {
                await send(
                    .routineDataTransferFinished(
                        success: false,
                        message: "Save failed: \(error.localizedDescription)"
                    )
                )
            }
        }
    }

    static func importData(
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: @escaping @Sendable () -> AppSettingsClient,
        notificationClient: @escaping @Sendable () -> NotificationClient
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                guard let result = try await SettingsRoutineDataTransferExecution.importData(
                    routineDataTransferClient: routineDataTransferClient,
                    modelContext: modelContext,
                    appSettingsClient: appSettingsClient,
                    notificationClient: notificationClient
                ) else {
                    await send(
                        .routineDataTransferFinished(
                            success: false,
                            message: "Load canceled."
                        )
                    )
                    return
                }

                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                NotificationCenter.default.postRoutineDidUpdate()
                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: "Loaded \(result.importedSummary.tasks) routines, \(result.importedSummary.places) places, and \(result.importedSummary.logs) logs."
                    )
                )
            } catch {
                await send(
                    .routineDataTransferFinished(
                        success: false,
                        message: "Load failed: \(error.localizedDescription)"
                    )
                )
            }
        }
    }
}
