import SwiftUI
import ComposableArchitecture

struct SettingsCloudDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("Actions") {
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

                Section("Status") {
                    if store.cloud.isCloudSyncInProgress || store.cloud.isCloudDataResetInProgress {
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

                Section("Estimated Usage") {
                    SettingsInfoRow(title: "Estimated iCloud Data", value: store.cloud.usageTotalText)
                    SettingsInfoRow(title: "Tasks", value: "\(store.cloud.cloudUsageEstimate.taskCount) • \(store.cloud.usageTaskPayloadText)")
                    SettingsInfoRow(title: "Logs", value: "\(store.cloud.cloudUsageEstimate.logCount) • \(store.cloud.usageLogPayloadText)")
                    SettingsInfoRow(title: "Places", value: "\(store.cloud.cloudUsageEstimate.placeCount) • \(store.cloud.usagePlacePayloadText)")
                    SettingsInfoRow(title: "Goals", value: "\(store.cloud.cloudUsageEstimate.goalCount) • \(store.cloud.usageGoalPayloadText)")
                    SettingsInfoRow(title: "Images", value: "\(store.cloud.cloudUsageEstimate.imageCount) • \(store.cloud.usageImagePayloadText)")

                    Text(store.cloud.usageSummaryText)
                        .foregroundStyle(.secondary)
                    Text(store.cloud.usageFootnoteText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("iCloud")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Delete iCloud Data?",
                isPresented: cloudDataResetConfirmationBinding
            ) {
                Button("Delete Data", role: .destructive) {
                    store.send(.resetCloudDataConfirmed)
                }
                Button("Cancel", role: .cancel) {
                    store.send(.setCloudDataResetConfirmation(false))
                }
            } message: {
                Text("This permanently deletes all Routina data from iCloud and from this device.")
            }
        }
    }

    private var actionsDisabled: Bool {
        store.cloud.isCloudSyncInProgress ||
        store.cloud.isCloudDataResetInProgress ||
        !store.cloud.cloudSyncAvailable
    }

    private var cloudDataResetConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.cloud.isCloudDataResetConfirmationPresented },
            set: { store.send(.setCloudDataResetConfirmation($0)) }
        )
    }
}
