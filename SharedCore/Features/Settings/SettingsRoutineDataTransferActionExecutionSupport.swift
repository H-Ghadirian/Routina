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
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: @escaping @Sendable () -> AppSettingsClient,
        notificationClient: @escaping @Sendable () -> NotificationClient
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsRoutineDataTransferEditor.begin(.import, state: &state) else {
            return .none
        }

        return importData(
            from: sourceURL,
            routineDataTransferClient: routineDataTransferClient,
            modelContext: modelContext,
            appSettingsClient: appSettingsClient,
            notificationClient: notificationClient
        )
    }

    static func beginVerification(
        state: inout SettingsDataTransferState,
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsRoutineDataTransferEditor.begin(.verify, state: &state) else {
            return .none
        }
        return verifyData(
            routineDataTransferClient: routineDataTransferClient,
            modelContext: modelContext
        )
    }

    static func beginVerification(
        from sourceURL: URL,
        state: inout SettingsDataTransferState,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsRoutineDataTransferEditor.begin(.verify, state: &state) else {
            return .none
        }
        return verifyData(from: sourceURL, modelContext: modelContext)
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
                        message: exportSuccessMessage(for: result)
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
                        message: exportSuccessMessage(for: result)
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
                send(.recoveryPointsLoaded(result.recoveryPoints))
                NotificationCenter.default.postRoutineDidUpdate()
                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: importSuccessMessage(for: result)
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
        routineDataTransferClient: RoutineDataTransferClient,
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
                    notificationClient: notificationClient,
                    recoveryDirectoryURL: routineDataTransferClient.recoveryDirectoryURL
                )

                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                send(.recoveryPointsLoaded(result.recoveryPoints))
                NotificationCenter.default.postRoutineDidUpdate()
                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: importSuccessMessage(for: result)
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

    static func verifyData(
        routineDataTransferClient: RoutineDataTransferClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                guard let result = try await SettingsRoutineDataTransferExecution.verifyData(
                    routineDataTransferClient: routineDataTransferClient,
                    modelContext: modelContext
                ) else {
                    await send(.routineDataTransferFinished(
                        success: false,
                        message: "Verification canceled."
                    ))
                    return
                }
                await send(.routineDataTransferFinished(
                    success: true,
                    message: verificationMessage(for: result)
                ))
            } catch {
                await send(.routineDataTransferFinished(
                    success: false,
                    message: "Verification failed: \(error.localizedDescription)"
                ))
            }
        }
    }

    static func verifyData(
        from sourceURL: URL,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                let result = try SettingsRoutineDataTransferExecution.verifyData(
                    from: sourceURL,
                    modelContext: modelContext
                )
                await send(.routineDataTransferFinished(
                    success: true,
                    message: verificationMessage(for: result)
                ))
            } catch {
                await send(.routineDataTransferFinished(
                    success: false,
                    message: "Verification failed: \(error.localizedDescription)"
                ))
            }
        }
    }

    static func loadRecoveryPoints(
        routineDataTransferClient: RoutineDataTransferClient
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            send(.recoveryPointsLoaded(
                SettingsRoutineDataTransferExecution.recoveryPoints(
                    routineDataTransferClient: routineDataTransferClient
                )
            ))
        }
    }

    private static func exportSuccessMessage(
        for result: SettingsRoutineDataTransferExportResult
    ) -> String {
        guard let verification = result.verification else {
            return "Saved to \(result.destinationFileName)."
        }
        return "Saved and verified \(verification.audit.totalRecordCount) records and \(verification.audit.attachmentCount) attachments in \(result.destinationFileName)."
    }

    private static func verificationMessage(
        for result: SettingsRoutineDataTransferVerificationResult
    ) -> String {
        let originText = result.verification.assurance.isSourceVerified
            ? "Its source verification receipt is valid"
            : "It has no source verification receipt, but its isolated restore passed"
        if result.comparison.matchesLiveData {
            return "\(originText), and its \(result.comparison.packageReport.totalRecordCount) records match this device."
        }
        let path = result.comparison.firstDifferencePath ?? "$"
        return "\(originText), but it differs from this device at \(path). No data was changed."
    }

    private static func importSuccessMessage(
        for result: SettingsRoutineDataTransferImportResult
    ) -> String {
        let summary = result.importedSummary
        var parts = [
            "\(summary.tasks) tasks",
            "\(summary.goals) goals",
            "\(summary.places) places",
            "\(summary.logs) logs",
            "\(summary.sleepSessions) sleep sessions"
        ]
        if SharedDefaults.app[.appSettingAwayEnabled] {
            parts.append("\(summary.awaySessions) away sessions")
        }
        parts.append("\(summary.placeCheckInSessions) place check-ins")
        parts.append("\(summary.emotionLogs) emotions")
        if SharedDefaults.app[.appSettingNotesEnabled] {
            parts.append("\(summary.notes) notes")
        }
        parts.append("\(summary.events) events")
        parts.append("\(summary.attachments) attachments")
        let verificationText = result.verification.assurance.isSourceVerified
            ? "Verified source receipt and isolated restore."
            : "Isolated restore passed; this older backup has no source verification receipt."
        let recoveryText = result.recoveryPoint == nil
            ? ""
            : " The previous device data was saved as a verified recovery point."
        let notificationText = result.notificationWarning == nil
            ? ""
            : " Data was restored, but notifications could not be refreshed; reopen Settings to retry."
        return "\(verificationText) Loaded \(formattedList(parts)).\(recoveryText)\(notificationText)"
    }

    private static func formattedList(_ parts: [String]) -> String {
        switch parts.count {
        case 0:
            return "nothing"
        case 1:
            return parts[0]
        case 2:
            return "\(parts[0]) and \(parts[1])"
        default:
            return parts.dropLast().joined(separator: ", ") + ", and \(parts.last ?? "")"
        }
    }
}
