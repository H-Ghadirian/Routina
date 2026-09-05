import ComposableArchitecture

extension SettingsFeature {
    func reduceDataTransferSelectionActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .exportRoutineDataTapped:
            return SettingsRoutineDataTransferActionExecution.beginExport(
                state: &state.dataTransfer,
                routineDataTransferClient: routineDataTransferClient,
                modelContext: modelContext
            )
        case let .exportRoutineDataDestinationSelected(destinationURL):
            return SettingsRoutineDataTransferActionExecution.beginExport(
                to: destinationURL,
                state: &state.dataTransfer,
                modelContext: modelContext
            )
        case .importRoutineDataTapped:
            return SettingsRoutineDataTransferActionExecution.beginImport(
                state: &state.dataTransfer,
                routineDataTransferClient: routineDataTransferClient,
                modelContext: modelContext,
                appSettingsClient: { appSettingsClient },
                notificationClient: { notificationClient }
            )
        case let .importRoutineDataSourceSelected(sourceURL):
            return SettingsRoutineDataTransferActionExecution.beginImport(
                from: sourceURL,
                state: &state.dataTransfer,
                routineDataTransferClient: routineDataTransferClient,
                modelContext: modelContext,
                appSettingsClient: { appSettingsClient },
                notificationClient: { notificationClient }
            )
        case .verifyRoutineDataTapped:
            return SettingsRoutineDataTransferActionExecution.beginVerification(
                state: &state.dataTransfer,
                routineDataTransferClient: routineDataTransferClient,
                modelContext: modelContext
            )
        case let .verifyRoutineDataSourceSelected(sourceURL):
            return SettingsRoutineDataTransferActionExecution.beginVerification(
                from: sourceURL,
                state: &state.dataTransfer,
                modelContext: modelContext
            )
        default:
            return .none
        }
    }

    func reduceRecoveryPointActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .recoveryPointsLoaded(points):
            state.dataTransfer.recoveryPoints = points
            if let pendingID = state.dataTransfer.recoveryPointPendingRestore?.id {
                state.dataTransfer.recoveryPointPendingRestore = points.first {
                    $0.id == pendingID
                }
            }
            return .none
        case let .restoreRecoveryPointTapped(id):
            guard !state.dataTransfer.isDataTransferInProgress else { return .none }
            state.dataTransfer.recoveryPointPendingRestore = state.dataTransfer
                .recoveryPoints
                .first { $0.id == id }
            return .none
        case let .setRecoveryPointRestoreConfirmation(isPresented):
            if !isPresented {
                state.dataTransfer.recoveryPointPendingRestore = nil
            }
            return .none
        case .restoreRecoveryPointConfirmed:
            guard let recoveryPoint = state.dataTransfer.recoveryPointPendingRestore else {
                return .none
            }
            state.dataTransfer.recoveryPointPendingRestore = nil
            return SettingsRoutineDataTransferActionExecution.beginImport(
                from: recoveryPoint.packageURL,
                state: &state.dataTransfer,
                routineDataTransferClient: routineDataTransferClient,
                modelContext: modelContext,
                appSettingsClient: { appSettingsClient },
                notificationClient: { notificationClient }
            )
        default:
            return .none
        }
    }

    func reduceDataTransferCompletionActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .routineDataTransferFinished(success, message):
            let completedOperation = state.dataTransfer.activeOperation
            if success, completedOperation == .export {
                state.dataTransfer.lastSuccessfulBackupDate = now
                appSettingsClient.setLastRoutineDataBackupDate(now)
            }
            SettingsRoutineDataTransferEditor.finish(
                message: message,
                state: &state.dataTransfer
            )
            return .none
        default:
            return .none
        }
    }
}
