import ComposableArchitecture
import Foundation
import SwiftData

extension SettingsFeature {
    func handleExportRoutineDataTapped(state: inout State) -> Effect<Action> {
        guard !state.isDataTransferInProgress else {
            return .none
        }

        state.isDataTransferInProgress = true
        state.dataTransferStatusMessage = "Saving routine data..."
        return .run { @MainActor send in
            do {
                guard let destinationURL = await PlatformSupport.selectRoutineDataExportURL(
                    suggestedFileName: defaultRoutineDataBackupFileName()
                ) else {
                    await send(
                        .routineDataTransferFinished(
                            success: false,
                            message: "Save canceled."
                        )
                    )
                    return
                }

                let context = modelContext()
                if context.hasChanges {
                    try context.save()
                }

                let backupData = try buildRoutineDataBackupJSON(from: context)
                try withSecurityScopedAccess(to: destinationURL) {
                    try backupData.write(to: destinationURL, options: .atomic)
                }

                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: "Saved to \(destinationURL.lastPathComponent)."
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

    func handleImportRoutineDataTapped(state: inout State) -> Effect<Action> {
        guard !state.isDataTransferInProgress else {
            return .none
        }

        state.isDataTransferInProgress = true
        state.dataTransferStatusMessage = "Loading routine data..."
        return .run { @MainActor send in
            do {
                guard let sourceURL = await PlatformSupport.selectRoutineDataImportURL() else {
                    await send(
                        .routineDataTransferFinished(
                            success: false,
                            message: "Load canceled."
                        )
                    )
                    return
                }

                let jsonData = try withSecurityScopedAccess(to: sourceURL) {
                    try Data(contentsOf: sourceURL)
                }
                let context = modelContext()
                let importedSummary = try replaceAllRoutineData(with: jsonData, in: context)
                try await rescheduleNotificationsAfterImport(in: context)

                await send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
                NotificationCenter.default.postRoutineDidUpdate()
                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: "Loaded \(importedSummary.tasks) routines, \(importedSummary.places) places, and \(importedSummary.logs) logs."
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

