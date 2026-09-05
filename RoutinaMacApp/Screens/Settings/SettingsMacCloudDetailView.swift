import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct SettingsMacCloudDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var isBackupExporterPresented = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areEventEmotionActionsEnabled = false

    var body: some View {
        let usageVisibility = SettingsCloudUsageVisibility(
            isPlacesEnabled: isPlacesEnabled,
            isGoalsEnabled: isGoalsTabEnabled,
            areEventEmotionActionsEnabled: areEventEmotionActionsEnabled,
            isNotesEnabled: isNotesEnabled
        )
        SettingsMacDetailShell(
            title: "iCloud & Backup",
            subtitle: "Sync tasks across devices, save backup packages, and manage the cloud copy when needed."
        ) {
            SettingsMacDetailCard(title: "iCloud") {
                HStack(spacing: 10) {
                    Button {
                        store.send(.syncNowTapped)
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath.icloud")
                    }
                    .buttonStyle(.bordered)
                    .disabled(actionsDisabled)

                    Button(role: .destructive) {
                        store.send(.setCloudDataResetConfirmation(true))
                    } label: {
                        Label("Delete App & iCloud Data", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(actionsDisabled)

                    if store.cloud.isCloudDataResetAuthenticationInProgress || store.cloud.isCloudDataResetInProgress {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if store.cloud.isCloudSyncInProgress {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .accessibilityLabel("Receiving iCloud data")
                            .accessibilityValue(store.cloud.syncStatusText)
                        Text(store.cloud.syncStatusText)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(store.cloud.syncStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsMacDetailCard(title: "Data Backup") {
                HStack(spacing: 10) {
                    Button {
                        isBackupExporterPresented = true
                    } label: {
                        Label("Save and Verify", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.dataTransfer.isDataTransferInProgress)

                    Button {
                        store.send(.verifyRoutineDataTapped)
                    } label: {
                        Label("Verify Backup", systemImage: "checkmark.shield")
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.dataTransfer.isDataTransferInProgress)

                    Button {
                        store.send(.importRoutineDataTapped)
                    } label: {
                        Label("Restore Backup", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.dataTransfer.isDataTransferInProgress)

                    if store.dataTransfer.isDataTransferInProgress {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if store.dataTransfer.shouldShowStatusText {
                    Text(store.dataTransfer.statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(store.dataTransfer.backupFreshnessText())
                    .font(.footnote)
                    .foregroundStyle(
                        store.dataTransfer.hasRecentSuccessfulBackup() ? Color.secondary : Color.red
                    )

                if !store.dataTransfer.recoveryPoints.isEmpty {
                    Divider()

                    Text("Restore Recovery")
                        .font(.headline)

                    ForEach(store.dataTransfer.recoveryPoints) { point in
                        Button {
                            store.send(.restoreRecoveryPointTapped(point.id))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(point.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    Text("\(point.totalRecordCount) records • \(point.attachmentCount) attachments")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(store.dataTransfer.isDataTransferInProgress)
                    }

                    Text(
                        """
                        Routina keeps the ten most recent verified snapshots created immediately before a restore. \
                        They remain only while Routina is installed.
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            SettingsMacDetailCard(title: "Estimated Usage") {
                settingsInfoRow(title: "Estimated iCloud Data", value: store.cloud.usageTotalText)
                settingsInfoRow(title: "Tasks", value: "\(store.cloud.cloudUsageEstimate.taskCount) • \(store.cloud.usageTaskPayloadText)")
                settingsInfoRow(title: "Logs", value: "\(store.cloud.cloudUsageEstimate.logCount) • \(store.cloud.usageLogPayloadText)")
                if usageVisibility.shows(.places) {
                    settingsInfoRow(
                        title: "Places", value: "\(store.cloud.cloudUsageEstimate.placeCount) • \(store.cloud.usagePlacePayloadText)")
                }
                if usageVisibility.shows(.goals) {
                    settingsInfoRow(
                        title: "Goals", value: "\(store.cloud.cloudUsageEstimate.goalCount) • \(store.cloud.usageGoalPayloadText)")
                }
                if usageVisibility.shows(.emotions) {
                    settingsInfoRow(
                        title: "Emotions",
                        value: "\(store.cloud.cloudUsageEstimate.emotionLogCount) • \(store.cloud.usageEmotionPayloadText)")
                }
                if usageVisibility.shows(.notes) {
                    settingsInfoRow(
                        title: "Notes", value: "\(store.cloud.cloudUsageEstimate.noteCount) • \(store.cloud.usageNotePayloadText)")
                }
                if usageVisibility.shows(.events) {
                    settingsInfoRow(
                        title: "Events", value: "\(store.cloud.cloudUsageEstimate.eventCount) • \(store.cloud.usageEventPayloadText)")
                }
                settingsInfoRow(
                    title: "Images", value: "\(store.cloud.cloudUsageEstimate.imageCount) • \(store.cloud.usageImagePayloadText)")
                if usageVisibility.shows(.voiceNotes) {
                    settingsInfoRow(
                        title: "Voice Notes",
                        value: "\(store.cloud.cloudUsageEstimate.voiceNoteCount) • \(store.cloud.usageVoiceNotePayloadText)")
                }

                Text(store.cloud.usageSummaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(store.cloud.usageFootnoteText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .fileExporter(
            isPresented: $isBackupExporterPresented,
            document: RoutineBackupExportPlaceholderDocument(),
            contentType: .routinaBackupPackage,
            defaultFilename: SettingsRoutineDataPersistence.defaultBackupFileName()
        ) { result in
            switch result {
            case let .success(destinationURL):
                store.send(.exportRoutineDataDestinationSelected(destinationURL))

            case let .failure(error):
                store.send(
                    .routineDataTransferFinished(
                        success: false,
                        message: "Save failed: \(error.localizedDescription)"
                    ))
            }
        }
        .alert(
            "Restore Recovery Point?",
            isPresented: recoveryPointRestoreConfirmationBinding
        ) {
            Button("Cancel", role: .cancel) {
                store.send(.setRecoveryPointRestoreConfirmation(false))
            }
            Button("Restore", role: .destructive) {
                store.send(.restoreRecoveryPointConfirmed)
            }
        } message: {
            if let point = store.dataTransfer.recoveryPointPendingRestore {
                Text(
                    "Restore the verified snapshot from \(point.createdAt.formatted(date: .abbreviated, time: .shortened))? Routina will preserve the current data as another recovery point first."
                )
            }
        }
    }

    private var actionsDisabled: Bool {
        store.cloud.isCloudSyncInProgress || store.cloud.isCloudDataResetAuthenticationInProgress || store.cloud.isCloudDataResetInProgress
            || !store.cloud.cloudSyncAvailable
    }

    private var recoveryPointRestoreConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.dataTransfer.recoveryPointPendingRestore != nil },
            set: { store.send(.setRecoveryPointRestoreConfirmation($0)) }
        )
    }
}
private struct RoutineBackupExportPlaceholderDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.routinaBackupPackage] }
    static var writableContentTypes: [UTType] { [.routinaBackupPackage] }

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(directoryWithFileWrappers: [:])
    }
}

private extension UTType {
    static var routinaBackupPackage: UTType {
        UTType(filenameExtension: SettingsRoutineDataPersistence.backupPackageExtension) ?? .package
    }
}
