import ComposableArchitecture
import Foundation
import SwiftData
import SwiftUI

enum SettingsMacSection: String, CaseIterable, Identifiable, Hashable {
    case notifications
    case places
    case tags
    case appearance
    case iCloud
    case backup
    case support
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notifications: return "Notifications"
        case .places:        return "Places"
        case .tags:          return "Tags"
        case .appearance:    return "Appearance"
        case .iCloud:        return "iCloud"
        case .backup:        return "Data Backup"
        case .support:       return "Support"
        case .about:         return "About"
        }
    }

    var icon: String {
        switch self {
        case .notifications: return "bell.badge.fill"
        case .places:        return "mappin.and.ellipse"
        case .tags:          return "tag.fill"
        case .appearance:    return "app.badge.fill"
        case .iCloud:        return "icloud.fill"
        case .backup:        return "externaldrive.fill"
        case .support:       return "envelope.fill"
        case .about:         return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .notifications: return .red
        case .places:        return .blue
        case .tags:          return .pink
        case .appearance:    return .orange
        case .iCloud:        return .cyan
        case .backup:        return .indigo
        case .support:       return .green
        case .about:         return .gray
        }
    }
}

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

                send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
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
