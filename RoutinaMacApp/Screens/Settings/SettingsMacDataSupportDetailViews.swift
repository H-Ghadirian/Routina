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

struct SettingsMacShortcutsDetailView: View {
    private let keyboardShortcuts: [SettingsMacShortcutRowModel] = [
        SettingsMacShortcutRowModel(title: "Add Task", detail: "Open quick task creation.", shortcut: "⌥⌘N"),
        SettingsMacShortcutRowModel(title: "Routines", detail: "Switch the sidebar back to routines.", shortcut: "⌥⌘1"),
        SettingsMacShortcutRowModel(title: "Stats", detail: "Open stats from anywhere in the app.", shortcut: "⌥⌘2"),
        SettingsMacShortcutRowModel(title: "Timeline", detail: "Open the done timeline.", shortcut: "⌥⌘3"),
        SettingsMacShortcutRowModel(title: "Save", detail: "Confirm supported edit sheets and dialogs.", shortcut: "Return"),
        SettingsMacShortcutRowModel(title: "Cancel", detail: "Dismiss supported edit sheets and dialogs.", shortcut: "Esc"),
        SettingsMacShortcutRowModel(title: "Quit", detail: "Quit Routina from the menu bar extra or app menu.", shortcut: "⌘Q")
    ]

    private let appShortcuts: [SettingsMacShortcutRowModel] = [
        SettingsMacShortcutRowModel(title: "Quick Add", detail: "“Quick add in Routina” or “Add a task in Routina”", shortcut: "Shortcuts"),
        SettingsMacShortcutRowModel(title: "Mark Done", detail: "“Mark task done in Routina” or “Complete a task in Routina”", shortcut: "Shortcuts"),
        SettingsMacShortcutRowModel(title: "Start Focus", detail: "“Start focus in Routina” or “Focus with Routina”", shortcut: "Shortcuts"),
        SettingsMacShortcutRowModel(title: "Today", detail: "“What's due in Routina” or “Today in Routina”", shortcut: "Shortcuts")
    ]

    var body: some View {
        SettingsMacDetailShell(
            title: "Shortcuts",
            subtitle: "Review keyboard shortcuts and Apple Shortcuts that Routina exposes."
        ) {
            SettingsMacDetailCard(title: "Keyboard") {
                ForEach(keyboardShortcuts) { shortcut in
                    SettingsMacShortcutRow(shortcut: shortcut)
                }
            }

            SettingsMacDetailCard(title: "Apple Shortcuts & Siri") {
                ForEach(appShortcuts) { shortcut in
                    SettingsMacShortcutRow(shortcut: shortcut)
                }
            }
        }
    }
}

struct SettingsMacQuickAddDetailView: View {
    var body: some View {
        SettingsMacDetailShell(
            title: "Quick Add",
            subtitle: "Use compact phrases to create todos, routines, deadlines, tags, places, priority, and focus estimates."
        ) {
            SettingsMacDetailCard(title: "Examples") {
                ForEach(SettingsQuickAddSyntaxGuide.examples) { example in
                    SettingsMacQuickAddExampleRow(example: example)
                }
            }

            ForEach(SettingsQuickAddSyntaxGuide.syntaxGroups) { group in
                SettingsMacDetailCard(title: group.title) {
                    ForEach(group.rows) { row in
                        SettingsMacQuickAddSyntaxRow(row: row)
                    }
                }
            }

            SettingsMacDetailCard(title: "Notes") {
                ForEach(SettingsQuickAddSyntaxGuide.notes, id: \.self) { note in
                    Label(note, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct SettingsMacQuickAddExampleRow: View {
    let example: SettingsQuickAddExample

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(example.phrase)
                .font(.subheadline.weight(.semibold).monospaced())
                .textSelection(.enabled)

            Text(example.result)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
    }
}

private struct SettingsMacQuickAddSyntaxRow: View {
    let row: SettingsQuickAddSyntaxItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.syntax)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.mint.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.mint.opacity(0.28), lineWidth: 1)
                )

            Text(row.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct SettingsMacShortcutRowModel: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let shortcut: String
}

private struct SettingsMacShortcutRow: View {
    let shortcut: SettingsMacShortcutRowModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(shortcut.title)
                    .font(.subheadline.weight(.semibold))

                Text(shortcut.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Text(shortcut.shortcut)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
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
