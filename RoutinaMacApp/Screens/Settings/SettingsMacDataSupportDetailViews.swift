import SwiftUI
import ComposableArchitecture

struct SettingsMacCloudDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "iCloud",
                subtitle: "Keep your routines synced across devices and manage the cloud copy when needed."
            ) {
                SettingsMacDetailCard(title: "Actions") {
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
                            Label("Delete iCloud Data", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(actionsDisabled)

                        if store.cloud.isCloudSyncInProgress || store.cloud.isCloudDataResetInProgress {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                SettingsMacDetailCard(title: "Status") {
                    Text(store.cloud.syncStatusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Estimated Usage") {
                    settingsInfoRow(title: "Estimated iCloud Data", value: store.cloud.usageTotalText)
                    settingsInfoRow(title: "Tasks", value: "\(store.cloud.cloudUsageEstimate.taskCount) • \(store.cloud.usageTaskPayloadText)")
                    settingsInfoRow(title: "Logs", value: "\(store.cloud.cloudUsageEstimate.logCount) • \(store.cloud.usageLogPayloadText)")
                    settingsInfoRow(title: "Places", value: "\(store.cloud.cloudUsageEstimate.placeCount) • \(store.cloud.usagePlacePayloadText)")
                    settingsInfoRow(title: "Goals", value: "\(store.cloud.cloudUsageEstimate.goalCount) • \(store.cloud.usageGoalPayloadText)")
                    settingsInfoRow(title: "Images", value: "\(store.cloud.cloudUsageEstimate.imageCount) • \(store.cloud.usageImagePayloadText)")

                    Text(store.cloud.usageSummaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(store.cloud.usageFootnoteText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionsDisabled: Bool {
        store.cloud.isCloudSyncInProgress ||
        store.cloud.isCloudDataResetInProgress ||
        !store.cloud.cloudSyncAvailable
    }
}

struct SettingsMacBackupDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Data Backup",
                subtitle: "Export your routines as JSON or bring a previous backup back into Routina."
            ) {
                SettingsMacDetailCard(title: "JSON Backup") {
                    HStack(spacing: 10) {
                        Button {
                            store.send(.exportRoutineDataTapped)
                        } label: {
                            Label("Save JSON", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.dataTransfer.isDataTransferInProgress)

                        Button {
                            store.send(.importRoutineDataTapped)
                        } label: {
                            Label("Load JSON", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.dataTransfer.isDataTransferInProgress)

                        if store.dataTransfer.isDataTransferInProgress {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    Text(store.dataTransfer.statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SettingsMacSupportDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        SettingsMacDetailShell(
            title: "Support",
            subtitle: "Reach out if something feels off or you want help with Routina."
        ) {
            SettingsMacDetailCard(title: "Contact") {
                Button {
                    store.send(.contactUsTapped)
                } label: {
                    Label("Email Support", systemImage: "envelope")
                }
                .buttonStyle(.borderedProminent)

                Text("h.qadirian@gmail.com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SettingsMacAboutDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "About",
                subtitle: "Version details and, if unlocked, the app’s diagnostic information."
            ) {
                SettingsMacDetailCard(title: "App") {
                    settingsInfoRow(title: "Version", value: store.diagnostics.appVersion)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 5) {
                            store.send(.aboutSectionLongPressed)
                        }
                }

                if store.diagnostics.isDebugSectionVisible {
                    SettingsMacDetailCard(title: "Diagnostics") {
                        settingsInfoRow(title: "Data Mode", value: store.diagnostics.dataModeDescription)
                        settingsInfoRow(title: "iCloud Container", value: store.diagnostics.iCloudContainerDescription)

                        Text("Last CloudKit Event: \(store.diagnostics.cloudDiagnosticsTimestamp)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(store.diagnostics.cloudDiagnosticsSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(store.diagnostics.pushDiagnosticsStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
