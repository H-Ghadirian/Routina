import Foundation
import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct SettingsCloudDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var isBackupExporterPresented = false
    @State private var isBackupImporterPresented = false

    var body: some View {
List {
    Section("iCloud") {
        Button {
            store.send(.syncNowTapped)
        } label: {
            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath.icloud")
        }
        .disabled(actionsDisabled)

        Button(role: .destructive) {
            store.send(.setCloudDataResetConfirmation(true))
        } label: {
            Label("Delete iCloud Data", systemImage: "trash")
        }
        .disabled(actionsDisabled)
    }

    Section("Data Backup") {
        Button {
            isBackupExporterPresented = true
        } label: {
            Label("Export Routine Data", systemImage: "square.and.arrow.down")
        }
        .disabled(store.dataTransfer.isDataTransferInProgress)

        Button {
            isBackupImporterPresented = true
        } label: {
            Label("Import Routine Data", systemImage: "square.and.arrow.up")
        }
        .disabled(store.dataTransfer.isDataTransferInProgress)
    }

    Section("iCloud Status") {
        if store.cloud.isCloudSyncInProgress ||
            store.cloud.isCloudDataResetAuthenticationInProgress ||
            store.cloud.isCloudDataResetInProgress {
            HStack(spacing: 10) {
                ProgressView()
                Text(store.cloud.syncStatusText)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(store.cloud.syncStatusText)
                .foregroundStyle(.secondary)
        }
    }

    Section("Backup Status") {
        if store.dataTransfer.isDataTransferInProgress {
            HStack(spacing: 10) {
                ProgressView()
                Text(store.dataTransfer.statusText)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(store.dataTransfer.statusText)
                .foregroundStyle(.secondary)
        }
    }

    Section("Estimated Usage") {
        SettingsInfoRow(title: "Estimated iCloud Data", value: store.cloud.usageTotalText)
        SettingsInfoRow(title: "Tasks", value: "\(store.cloud.cloudUsageEstimate.taskCount) • \(store.cloud.usageTaskPayloadText)")
        SettingsInfoRow(title: "Logs", value: "\(store.cloud.cloudUsageEstimate.logCount) • \(store.cloud.usageLogPayloadText)")
        SettingsInfoRow(title: "Places", value: "\(store.cloud.cloudUsageEstimate.placeCount) • \(store.cloud.usagePlacePayloadText)")
        SettingsInfoRow(title: "Goals", value: "\(store.cloud.cloudUsageEstimate.goalCount) • \(store.cloud.usageGoalPayloadText)")
        SettingsInfoRow(title: "Emotions", value: "\(store.cloud.cloudUsageEstimate.emotionLogCount) • \(store.cloud.usageEmotionPayloadText)")
        SettingsInfoRow(title: "Notes", value: "\(store.cloud.cloudUsageEstimate.noteCount) • \(store.cloud.usageNotePayloadText)")
        SettingsInfoRow(title: "Events", value: "\(store.cloud.cloudUsageEstimate.eventCount) • \(store.cloud.usageEventPayloadText)")
        SettingsInfoRow(title: "Images", value: "\(store.cloud.cloudUsageEstimate.imageCount) • \(store.cloud.usageImagePayloadText)")
        SettingsInfoRow(title: "Voice Notes", value: "\(store.cloud.cloudUsageEstimate.voiceNoteCount) • \(store.cloud.usageVoiceNotePayloadText)")

        Text(store.cloud.usageSummaryText)
            .foregroundStyle(.secondary)
        Text(store.cloud.usageFootnoteText)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
.listStyle(.insetGrouped)
.navigationTitle("iCloud & Backup")
.navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: cloudDataResetConfirmationBinding) {
        SettingsCloudDataResetConfirmationSheet(store: store)
    }
    .fileExporter(
        isPresented: $isBackupExporterPresented,
        document: SettingsIOSRoutineBackupExportDocument(),
        contentType: .routinaBackupPackage,
        defaultFilename: SettingsRoutineDataPersistence.defaultBackupFileName()
    ) { result in
        switch result {
        case let .success(destinationURL):
            store.send(.exportRoutineDataDestinationSelected(destinationURL))

        case let .failure(error):
            store.send(.routineDataTransferFinished(
                success: false,
                message: dataTransferFailureMessage(
                    prefix: "Save",
                    canceledMessage: "Save canceled.",
                    error: error
                )
            ))
        }
    }
    .fileImporter(
        isPresented: $isBackupImporterPresented,
        allowedContentTypes: [.routinaBackupPackage, .folder, .json]
    ) { result in
        switch result {
        case let .success(sourceURL):
            store.send(.importRoutineDataSourceSelected(sourceURL))

        case let .failure(error):
            store.send(.routineDataTransferFinished(
                success: false,
                message: dataTransferFailureMessage(
                    prefix: "Load",
                    canceledMessage: "Load canceled.",
                    error: error
                )
            ))
        }
    }
    }

    private var actionsDisabled: Bool {
        store.cloud.isCloudSyncInProgress ||
        store.cloud.isCloudDataResetAuthenticationInProgress ||
        store.cloud.isCloudDataResetInProgress ||
        !store.cloud.cloudSyncAvailable
    }

    private var cloudDataResetConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.cloud.isCloudDataResetConfirmationPresented },
            set: { store.send(.setCloudDataResetConfirmation($0)) }
        )
    }

    private func dataTransferFailureMessage(
        prefix: String,
        canceledMessage: String,
        error: Error
    ) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
            return canceledMessage
        }
        return "\(prefix) failed: \(error.localizedDescription)"
    }
}

private struct SettingsCloudDataResetConfirmationSheet: View {
    let store: StoreOf<SettingsFeature>

    @Environment(\.dismiss) private var dismiss
    @State private var isBackupExporterPresented = false

    var body: some View {
NavigationStack {
    Form {
        Section("Back Up First") {
            Text("Save a Routina backup before deleting iCloud data so you have a recovery point.")
                .foregroundStyle(.secondary)

            Button {
                isBackupExporterPresented = true
            } label: {
                Label("Save Backup First", systemImage: "square.and.arrow.down")
            }
            .disabled(store.dataTransfer.isDataTransferInProgress)

            if store.dataTransfer.isDataTransferInProgress {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(store.dataTransfer.statusText)
                        .foregroundStyle(.secondary)
                }
            } else if !store.dataTransfer.dataTransferStatusMessage.isEmpty {
                Text(store.dataTransfer.dataTransferStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            Text("This permanently deletes all Routina data from iCloud and from this device.")
                .foregroundStyle(.secondary)
        }

        Section("App Lock") {
            if store.appearance.isAppLockEnabled {
                Label("App Lock is on", systemImage: "lock.fill")
                Text("Routina will ask for \(store.appearance.appLockMethodDescription) before deleting iCloud data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Turn on App Lock before deleting iCloud data. Routina will use \(store.appearance.appLockMethodDescription) to confirm this action.")
                    .foregroundStyle(.secondary)

                Button {
                    store.send(.appLockToggled(true))
                } label: {
                    Label("Turn On App Lock", systemImage: "lock")
                }
                .disabled(store.appearance.isAppLockToggleInProgress)
            }

            if store.appearance.isAppLockToggleInProgress ||
                store.cloud.isCloudDataResetAuthenticationInProgress {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(store.appearance.isAppLockToggleInProgress ? "Turning on App Lock..." : "Confirming App Lock...")
                        .foregroundStyle(.secondary)
                }
            } else if !store.appearance.appLockStatusMessage.isEmpty {
                Text(store.appearance.appLockStatusMessage)
                    .font(.caption)
                    .foregroundStyle(store.appearance.isAppLockEnabled ? Color.secondary : Color.red)
            } else if let reason = store.appearance.appLockUnavailableReason,
                      !store.appearance.isAppLockEnabled {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
    .navigationTitle("Delete iCloud Data")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                store.send(.setCloudDataResetConfirmation(false))
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Delete", role: .destructive) {
                store.send(.resetCloudDataConfirmed)
            }
            .disabled(deleteDisabled)
        }
    }
    .fileExporter(
        isPresented: $isBackupExporterPresented,
        document: SettingsIOSRoutineBackupExportDocument(),
        contentType: .routinaBackupPackage,
        defaultFilename: SettingsRoutineDataPersistence.defaultBackupFileName()
    ) { result in
        switch result {
        case let .success(destinationURL):
            store.send(.exportRoutineDataDestinationSelected(destinationURL))

        case let .failure(error):
            store.send(.routineDataTransferFinished(
                success: false,
                message: dataTransferFailureMessage(
                    prefix: "Save",
                    canceledMessage: "Save canceled.",
                    error: error
                )
            ))
        }
    }
}
    }

    private var deleteDisabled: Bool {
        !store.appearance.isAppLockEnabled ||
        store.appearance.isAppLockToggleInProgress ||
        store.cloud.isCloudDataResetAuthenticationInProgress ||
        store.cloud.isCloudDataResetInProgress
    }

    private func dataTransferFailureMessage(
        prefix: String,
        canceledMessage: String,
        error: Error
    ) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
            return canceledMessage
        }
        return "\(prefix) failed: \(error.localizedDescription)"
    }
}

private struct SettingsIOSRoutineBackupExportDocument: FileDocument {
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
