import CloudKit
import ComposableArchitecture
import SwiftData
import SwiftUI
import UserNotifications

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var appVersion: String = ""
        var dataModeDescription: String = AppEnvironment.dataModeLabel
        var iCloudContainerDescription: String = AppEnvironment.cloudKitContainerIdentifier ?? "Disabled"
        var cloudDiagnosticsSummary: String = CloudKitSyncDiagnostics.snapshot().summary
        var cloudDiagnosticsTimestamp: String = CloudKitSyncDiagnostics.snapshot().timestampText
        var pushDiagnosticsStatus: String = CloudKitSyncDiagnostics.snapshot().pushStatus
        var isDebugSectionVisible: Bool = false
        var cloudSyncAvailable: Bool = AppEnvironment.isCloudSyncEnabled
        var notificationsEnabled: Bool = SharedDefaults.app[.appSettingNotificationsEnabled]
        var systemSettingsNotificationsEnabled: Bool = true
        var isCloudSyncInProgress: Bool = false
        var isCloudDataResetInProgress: Bool = false
        var isCloudDataResetConfirmationPresented: Bool = false
        var cloudStatusMessage: String = ""
        var isDataTransferInProgress: Bool = false
        var dataTransferStatusMessage: String = ""
        var selectedAppIcon: AppIconOption = .persistedSelection
    }

    enum Action: Equatable {
        case toggleNotifications(Bool)
        case openAppSettingsTapped
        case onAppear
        case onAppBecameActive
        case contactUsTapped
        case aboutSectionLongPressed
        case systemNotificationPermissionChecked(Bool)
        case cloudDiagnosticsUpdated
        case syncNowTapped
        case setCloudDataResetConfirmation(Bool)
        case resetCloudDataConfirmed
        case exportRoutineDataTapped
        case importRoutineDataTapped
        case appIconSelected(AppIconOption)
        case routineDataTransferFinished(success: Bool, message: String)
        case cloudSyncFinished(success: Bool, message: String)
        case cloudDataResetFinished(success: Bool, message: String)
    }

    @Dependency(\.modelContext) var modelContext
    @Dependency(\.notificationClient) var notificationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleNotifications(let isOn):
                state.notificationsEnabled = isOn
                SharedDefaults.app[.appSettingNotificationsEnabled] = isOn
                return .none

            case .openAppSettingsTapped:
                if let url = PlatformSupport.notificationSettingsURL {
                    return .run { @MainActor _ in
                        PlatformSupport.open(url)
                    }
                }
                return .none

            case .onAppear:
                state.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                state.isDebugSectionVisible = false
                state.selectedAppIcon = .persistedSelection
                let diagnostics = CloudKitSyncDiagnostics.snapshot()
                state.cloudDiagnosticsSummary = diagnostics.summary
                state.cloudDiagnosticsTimestamp = diagnostics.timestampText
                state.pushDiagnosticsStatus = diagnostics.pushStatus
                return .run { @MainActor send in
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = settings.authorizationStatus == .authorized
                    send(.systemNotificationPermissionChecked(systemEnabled))
                }

            case .contactUsTapped:
                if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
                    return .run { @MainActor _ in
                        PlatformSupport.open(emailURL)
                    }
                }
                return .none

            case .aboutSectionLongPressed:
                state.isDebugSectionVisible = true
                return .none

            case let .systemNotificationPermissionChecked(value):
                state.systemSettingsNotificationsEnabled = value
                return .none

            case .cloudDiagnosticsUpdated:
                let diagnostics = CloudKitSyncDiagnostics.snapshot()
                state.cloudDiagnosticsSummary = diagnostics.summary
                state.cloudDiagnosticsTimestamp = diagnostics.timestampText
                state.pushDiagnosticsStatus = diagnostics.pushStatus
                return .none

            case .onAppBecameActive:
                return .run { @MainActor send in
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = settings.authorizationStatus == .authorized
                    send(.systemNotificationPermissionChecked(systemEnabled))
                }

            case .syncNowTapped:
                guard !state.isCloudDataResetInProgress else {
                    return .none
                }
                guard state.cloudSyncAvailable else {
                    state.cloudStatusMessage = "iCloud sync is disabled in this build."
                    return .none
                }

                state.isCloudSyncInProgress = true
                state.cloudStatusMessage = "Syncing with iCloud..."
                return .run { @MainActor send in
                    do {
                        let context = modelContext()
                        if context.hasChanges {
                            try context.save()
                        }
                        if let containerIdentifier = AppEnvironment.cloudKitContainerIdentifier {
                            try await CloudKitDirectPullService.pullLatestIntoLocalStore(
                                containerIdentifier: containerIdentifier,
                                modelContext: context
                            )
                        }
                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
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

            case let .setCloudDataResetConfirmation(isPresented):
                state.isCloudDataResetConfirmationPresented = isPresented
                return .none

            case .resetCloudDataConfirmed:
                state.isCloudDataResetConfirmationPresented = false

                guard !state.isCloudSyncInProgress,
                      !state.isCloudDataResetInProgress
                else {
                    return .none
                }

                guard state.cloudSyncAvailable,
                      let cloudContainerIdentifier = AppEnvironment.cloudKitContainerIdentifier
                else {
                    state.cloudStatusMessage = "iCloud sync is disabled in this build."
                    return .none
                }

                state.isCloudDataResetInProgress = true
                state.cloudStatusMessage = "Deleting iCloud data..."
                return .run { @MainActor send in
                    do {
                        try await CloudDataResetService.resetAllUserData(
                            cloudKitContainerIdentifier: cloudContainerIdentifier,
                            modelContext: modelContext()
                        )
                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
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
                                message: cloudDataResetErrorMessage(for: error)
                            )
                        )
                    }
                }

            case .exportRoutineDataTapped:
#if os(macOS)
                guard !state.isDataTransferInProgress else {
                    return .none
                }

                state.isDataTransferInProgress = true
                state.dataTransferStatusMessage = "Saving routine data..."
                return .run { @MainActor send in
                    do {
                        guard let destinationURL = PlatformSupport.selectRoutineDataExportURL(
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
#else
                return .none
#endif

            case .importRoutineDataTapped:
#if os(macOS)
                guard !state.isDataTransferInProgress else {
                    return .none
                }

                state.isDataTransferInProgress = true
                state.dataTransferStatusMessage = "Loading routine data..."
                return .run { @MainActor send in
                    do {
                        guard let sourceURL = PlatformSupport.selectRoutineDataImportURL() else {
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

                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                        await send(
                            .routineDataTransferFinished(
                                success: true,
                                message: "Loaded \(importedSummary.tasks) routines and \(importedSummary.logs) logs."
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
#else
                return .none
#endif

            case let .appIconSelected(option):
                state.selectedAppIcon = option
                AppIconOption.persist(option)
                return .run { @MainActor _ in
                    PlatformSupport.applyAppIcon(option)
                }

            case let .routineDataTransferFinished(_, message):
                state.isDataTransferInProgress = false
                state.dataTransferStatusMessage = message
                return .none

            case let .cloudSyncFinished(_, message):
                state.isCloudSyncInProgress = false
                state.cloudStatusMessage = message
                return .none

            case let .cloudDataResetFinished(_, message):
                state.isCloudDataResetInProgress = false
                state.cloudStatusMessage = message
                return .none
            }
        }
    }

    private func cloudDataResetErrorMessage(for error: Error) -> String {
        guard let cloudError = error as? CKError else {
            return "Data reset failed: \(error.localizedDescription)"
        }

        switch cloudError.code {
        case .notAuthenticated:
            return "Please sign in to iCloud and try again."
        case .networkUnavailable, .networkFailure:
            return "Network issue while deleting iCloud data. Please try again."
        case .serviceUnavailable, .requestRateLimited:
            return "iCloud is temporarily unavailable. Please try again shortly."
        default:
            return "Data reset failed: \(cloudError.localizedDescription)"
        }
    }

    private struct RoutineDataBackup: Codable {
        var schemaVersion: Int
        var exportedAt: Date
        var tasks: [Task]
        var logs: [Log]

        struct Task: Codable {
            var id: UUID
            var name: String?
            var emoji: String?
            var interval: Int
            var lastDone: Date?
        }

        struct Log: Codable {
            var id: UUID
            var timestamp: Date?
            var taskID: UUID
        }
    }

    private struct ImportSummary {
        var tasks: Int
        var logs: Int
    }

    private enum RoutineDataTransferError: LocalizedError {
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedSchema(version):
                return "Unsupported backup format version: \(version)."
            }
        }
    }

    private func defaultRoutineDataBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "routina-backup-\(formatter.string(from: Date())).json"
    }

    @MainActor
    private func buildRoutineDataBackupJSON(from context: ModelContext) throws -> Data {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        let backup = RoutineDataBackup(
            schemaVersion: 1,
            exportedAt: Date(),
            tasks: tasks.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    emoji: $0.emoji,
                    interval: max(Int($0.interval), 1),
                    lastDone: $0.lastDone
                )
            },
            logs: logs.map {
                .init(
                    id: $0.id,
                    timestamp: $0.timestamp,
                    taskID: $0.taskID
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    @MainActor
    private func replaceAllRoutineData(
        with jsonData: Data,
        in context: ModelContext
    ) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(RoutineDataBackup.self, from: jsonData)

        guard backup.schemaVersion == 1 else {
            throw RoutineDataTransferError.unsupportedSchema(backup.schemaVersion)
        }

        do {
            let existingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
            for log in existingLogs {
                context.delete(log)
            }

            let existingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
            for task in existingTasks {
                context.delete(task)
            }

            var importedTaskIDs = Set<UUID>()
            var importedTaskCount = 0
            for task in backup.tasks {
                guard importedTaskIDs.insert(task.id).inserted else { continue }

                let clampedInterval = min(max(task.interval, 1), Int(Int16.max))
                let importedTask = RoutineTask(
                    id: task.id,
                    name: task.name,
                    emoji: task.emoji,
                    interval: Int16(clampedInterval),
                    lastDone: task.lastDone
                )
                context.insert(importedTask)
                importedTaskCount += 1
            }

            var importedLogIDs = Set<UUID>()
            var importedLogCount = 0
            for log in backup.logs {
                guard importedTaskIDs.contains(log.taskID) else { continue }
                guard importedLogIDs.insert(log.id).inserted else { continue }

                let importedLog = RoutineLog(
                    id: log.id,
                    timestamp: log.timestamp,
                    taskID: log.taskID
                )
                context.insert(importedLog)
                importedLogCount += 1
            }

            try context.save()
            return ImportSummary(tasks: importedTaskCount, logs: importedLogCount)
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    private func rescheduleNotificationsAfterImport(in context: ModelContext) async throws {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks {
            let payload = NotificationPayload(
                identifier: task.id.uuidString,
                name: task.name,
                interval: max(Int(task.interval), 1),
                lastDone: task.lastDone
            )
            await notificationClient.schedule(payload)
        }
    }

    private func withSecurityScopedAccess<T>(
        to url: URL,
        _ operation: () throws -> T
    ) throws -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }
}
