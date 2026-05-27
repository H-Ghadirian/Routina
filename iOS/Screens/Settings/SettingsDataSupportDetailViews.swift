import SwiftUI
import ComposableArchitecture
import Foundation
import UniformTypeIdentifiers

struct SettingsDataBackupDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var isBackupExporterPresented = false
    @State private var isBackupImporterPresented = false

    var body: some View {
List {
    Section("Actions") {
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

    Section("Status") {
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
}
.listStyle(.insetGrouped)
.navigationTitle("Data Backup")
.navigationBarTitleDisplayMode(.inline)
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

struct SettingsAboutDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
List {
    Section("Contact") {
        Button {
            store.send(.contactUsTapped)
        } label: {
            Label("Email Support", systemImage: "envelope")
        }

        HStack {
            Text("Email")
            Spacer()
            Text("h.qadirian@gmail.com")
                .foregroundStyle(.secondary)
        }
    }

    Section("App") {
        HStack {
            Text("Version")
            Spacer()
            Text(store.diagnostics.appVersion)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 5) {
            store.send(.aboutSectionLongPressed)
        }
    }

    if store.diagnostics.isDebugSectionVisible {
        Section("Diagnostics") {
            SettingsInfoRow(title: "Data Mode", value: store.diagnostics.dataModeDescription)
            SettingsInfoRow(title: "iCloud Container", value: store.diagnostics.iCloudContainerDescription)

            Text("Last CloudKit Event: \(store.diagnostics.cloudDiagnosticsTimestamp)")
                .foregroundStyle(.secondary)
            Text(store.diagnostics.cloudDiagnosticsSummary)
                .foregroundStyle(.secondary)
            Text(store.diagnostics.pushDiagnosticsStatus)
                .foregroundStyle(.secondary)
        }
    }
}
.listStyle(.insetGrouped)
.navigationTitle("Support & About")
.navigationBarTitleDisplayMode(.inline)
    }
}
