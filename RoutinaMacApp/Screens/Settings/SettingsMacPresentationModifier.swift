import ComposableArchitecture
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsMacPresentationModifier: ViewModifier {
    let store: StoreOf<SettingsFeature>
    @Binding var isPlacePickerPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: cloudDataResetConfirmationBinding) {
                SettingsMacCloudDataResetConfirmationSheet(store: store)
            }
            .alert(
                "Delete Place?",
                isPresented: deletePlaceConfirmationBinding
            ) {
                Button("Delete", role: .destructive) {
                    store.send(.deletePlaceConfirmed)
                }
                Button("Cancel", role: .cancel) {
                    store.send(.setDeletePlaceConfirmation(false))
                }
            } message: {
                Text(store.places.deleteConfirmationMessage)
            }
            .sheet(isPresented: $isPlacePickerPresented) {
                PlaceLocationPickerSheet(
                    initialCoordinate: store.places.placeDraftCoordinate,
                    initialRadiusMeters: store.places.placeDraftRadiusMeters,
                    fallbackCoordinate: store.places.placeDraftCoordinate ?? store.places.lastKnownLocationCoordinate
                ) { coordinate, radiusMeters in
                    store.send(.placeDraftCoordinateChanged(coordinate))
                    store.send(.placeDraftRadiusChanged(radiusMeters))
                    isPlacePickerPresented = false
                } onCancel: {
                    isPlacePickerPresented = false
                }
            }
    }

    private var cloudDataResetConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.cloud.isCloudDataResetConfirmationPresented },
            set: { store.send(.setCloudDataResetConfirmation($0)) }
        )
    }

    private var deletePlaceConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.places.isDeletePlaceConfirmationPresented },
            set: { store.send(.setDeletePlaceConfirmation($0)) }
        )
    }
}

private struct SettingsMacCloudDataResetConfirmationSheet: View {
    let store: StoreOf<SettingsFeature>

    @Environment(\.dismiss) private var dismiss
    @State private var isBackupExporterPresented = false

    var body: some View {
VStack(alignment: .leading, spacing: 18) {
    VStack(alignment: .leading, spacing: 6) {
        Text("Delete iCloud Data")
            .font(.title3.bold())
        Text("Save a backup first, then create a deletion password if you still want to continue.")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    VStack(alignment: .leading, spacing: 10) {
        Text("Back Up First")
            .font(.headline)

        Text("Save a Routina backup before deleting iCloud data so you have a recovery point.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 10) {
            Button {
                isBackupExporterPresented = true
            } label: {
                Label("Save Backup First", systemImage: "square.and.arrow.down")
            }
            .disabled(store.dataTransfer.isDataTransferInProgress)

            if store.dataTransfer.isDataTransferInProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }

        if store.dataTransfer.isDataTransferInProgress ||
            !store.dataTransfer.dataTransferStatusMessage.isEmpty {
            Text(store.dataTransfer.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    Divider()

    Text("This permanently deletes all Routina data from iCloud and from this device.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

    VStack(alignment: .leading, spacing: 8) {
        Text("Deletion Password")
            .font(.headline)

        SecureField("Create Password", text: passwordBinding)
        SecureField("Re-enter Password", text: passwordConfirmationBinding)

        Text(store.cloud.cloudDataResetPasswordStatusText)
            .font(.caption)
            .foregroundStyle(store.cloud.isCloudDataResetPasswordReady ? Color.secondary : Color.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    HStack {
        Spacer()
        Button("Cancel") {
            store.send(.setCloudDataResetConfirmation(false))
            dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Button("Delete", role: .destructive) {
            store.send(.resetCloudDataConfirmed)
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!store.cloud.isCloudDataResetPasswordReady)
    }
}
.padding(24)
.frame(width: 420)
    .fileExporter(
        isPresented: $isBackupExporterPresented,
        document: SettingsMacCloudResetBackupExportDocument(),
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

    private var passwordBinding: Binding<String> {
        Binding(
            get: { store.cloud.cloudDataResetPasswordDraft },
            set: { store.send(.cloudDataResetPasswordChanged($0)) }
        )
    }

    private var passwordConfirmationBinding: Binding<String> {
        Binding(
            get: { store.cloud.cloudDataResetPasswordConfirmationDraft },
            set: { store.send(.cloudDataResetPasswordConfirmationChanged($0)) }
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

private struct SettingsMacCloudResetBackupExportDocument: FileDocument {
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

extension View {
    func settingsMacPresentations(
        store: StoreOf<SettingsFeature>,
        isPlacePickerPresented: Binding<Bool>
    ) -> some View {
        modifier(
            SettingsMacPresentationModifier(
                store: store,
                isPlacePickerPresented: isPlacePickerPresented
            )
        )
    }
}
