import SwiftUI
import ComposableArchitecture

struct SettingsCloudDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
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
.navigationTitle("iCloud")
.navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: cloudDataResetConfirmationBinding) {
        SettingsCloudDataResetConfirmationSheet(store: store)
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

private struct SettingsCloudDataResetConfirmationSheet: View {
    let store: StoreOf<SettingsFeature>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
NavigationStack {
    Form {
        Section {
            Text("This permanently deletes all Routina data from iCloud and from this device.")
                .foregroundStyle(.secondary)
        }

        Section("Deletion Password") {
            SecureField("Create Password", text: passwordBinding)
                .textContentType(.newPassword)
            SecureField("Re-enter Password", text: passwordConfirmationBinding)
                .textContentType(.newPassword)

            Text(store.cloud.cloudDataResetPasswordStatusText)
                .font(.caption)
                .foregroundStyle(store.cloud.isCloudDataResetPasswordReady ? Color.secondary : Color.red)
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
            .disabled(!store.cloud.isCloudDataResetPasswordReady)
        }
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
}
