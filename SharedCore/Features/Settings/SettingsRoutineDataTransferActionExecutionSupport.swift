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

    static func beginExport(
        to destinationURL: URL,
        state: inout SettingsDataTransferState,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsRoutineDataTransferEditor.begin(.export, state: &state) else {
            return .none
        }

        return exportData(to: destinationURL, modelContext: modelContext)
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

    static func beginImport(
        from sourceURL: URL,
        state: inout SettingsDataTransferState,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: @escaping @Sendable () -> AppSettingsClient,
        notificationClient: @escaping @Sendable () -> NotificationClient
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsRoutineDataTransferEditor.begin(.import, state: &state) else {
            return .none
        }

        return importData(
            from: sourceURL,
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

    static func exportData(
        to destinationURL: URL,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                let result = try await SettingsRoutineDataTransferExecution.exportData(
                    to: destinationURL,
                    modelContext: modelContext
                )

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
                        message: importSuccessMessage(for: result.importedSummary)
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

    static func importData(
        from sourceURL: URL,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: @escaping @Sendable () -> AppSettingsClient,
        notificationClient: @escaping @Sendable () -> NotificationClient
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                let result = try await SettingsRoutineDataTransferExecution.importData(
                    from: sourceURL,
                    modelContext: modelContext,
                    appSettingsClient: appSettingsClient,
                    notificationClient: notificationClient
                )

                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                NotificationCenter.default.postRoutineDidUpdate()
                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: importSuccessMessage(for: result.importedSummary)
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

    private static func importSuccessMessage(for summary: SettingsRoutineDataPersistence.ImportSummary) -> String {
        "Loaded \(summary.tasks) routines, \(summary.goals) goals, \(summary.places) places, \(summary.logs) logs, \(summary.sleepSessions) sleep sessions, \(summary.placeCheckInSessions) place check-ins, \(summary.emotionLogs) emotions, \(summary.notes) notes, \(summary.events) events, and \(summary.attachments) attachments."
    }
}
