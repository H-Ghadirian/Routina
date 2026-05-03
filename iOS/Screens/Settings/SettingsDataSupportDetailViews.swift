import SwiftUI
import ComposableArchitecture

struct SettingsDataBackupDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Actions") {
                    Button {
                        store.send(.exportRoutineDataTapped)
                    } label: {
                        Label("Export Routine Data", systemImage: "square.and.arrow.down")
                    }
                    .disabled(store.dataTransfer.isDataTransferInProgress)

                    Button {
                        store.send(.importRoutineDataTapped)
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
        }
    }
}

struct SettingsSupportDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
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
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsAboutDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
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
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
