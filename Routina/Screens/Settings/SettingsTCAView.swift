import ComposableArchitecture
import SwiftUI

struct SettingsTCAView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            settingsContent
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
            .onAppear {
                store.send(.onAppear)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
            ) { _ in
                store.send(.onAppBecameActive)
            }
            .onReceive(NotificationCenter.default.publisher(for: CloudKitSyncDiagnostics.didUpdateNotification)) { _ in
                store.send(.cloudDiagnosticsUpdated)
            }
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.notificationsEnabled },
            set: { store.send(.toggleNotifications($0)) }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { store.notificationReminderTime },
            set: { store.send(.notificationReminderTimeChanged($0)) }
        )
    }

    private var syncStatusText: String {
        if store.isCloudDataResetInProgress {
            return "Deleting iCloud data..."
        }
        if store.isCloudSyncInProgress {
            return "Syncing..."
        }
        if !store.cloudStatusMessage.isEmpty {
            return store.cloudStatusMessage
        }
        if !store.cloudSyncAvailable {
            return "iCloud sync is disabled in this build."
        }
        return "Ready to sync."
    }

    private var dataTransferStatusText: String {
        if store.isDataTransferInProgress {
            return "Processing JSON file..."
        }
        if !store.dataTransferStatusMessage.isEmpty {
            return store.dataTransferStatusMessage
        }
        return "Export or import all routine data as JSON."
    }

    private var cloudDataResetConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isCloudDataResetConfirmationPresented },
            set: { store.send(.setCloudDataResetConfirmation($0)) }
        )
    }

    @ViewBuilder
    private var settingsContent: some View {
        #if os(macOS)
        macSettingsContent
        #else
        NavigationStack {
            Form {
                notificationsFormSection
                supportFormSection
                iCloudFormSection
                aboutFormSection
                if store.isDebugSectionVisible {
                    debugFormSection
                }
            }
            .navigationTitle("Settings")
        }
        #endif
    }

    @ViewBuilder
    private var notificationsFormSection: some View {
        Section(header: Text("Notifications")) {
            Toggle("Enable notifications", isOn: notificationsBinding)

            DatePicker(
                "Reminder time",
                selection: reminderTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .disabled(store.notificationsEnabled == false)

            Text("Notifications include quick actions for Done and Snooze.")
                .font(.footnote)
                .foregroundColor(.secondary)

            if store.systemSettingsNotificationsEnabled == false {
                Button("Allow Notifications in System Settings") {
                    store.send(.openAppSettingsTapped)
                }
                .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private var supportFormSection: some View {
        Section(header: Text("Support")) {
            Button(action: {
                store.send(.contactUsTapped)
            }) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.blue)
                    Text("Contact Us")
                }
            }
        }
    }

    @ViewBuilder
    private var iCloudFormSection: some View {
        Section(header: Text("iCloud")) {
            Button {
                store.send(.syncNowTapped)
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                        .foregroundColor(.blue)
                    Text("Sync Now")
                }
            }
            .disabled(
                store.isCloudSyncInProgress ||
                store.isCloudDataResetInProgress ||
                !store.cloudSyncAvailable
            )

            Button(role: .destructive) {
                store.send(.setCloudDataResetConfirmation(true))
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Delete iCloud Data")
                }
            }
            .disabled(
                store.isCloudSyncInProgress ||
                store.isCloudDataResetInProgress ||
                !store.cloudSyncAvailable
            )

            if store.isCloudSyncInProgress || store.isCloudDataResetInProgress {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(syncStatusText)
                        .foregroundColor(.secondary)
                }
            } else if !store.cloudStatusMessage.isEmpty {
                Text(store.cloudStatusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var aboutFormSection: some View {
        Section(header: Text("About")) {
            HStack {
                Text("App Version")
                Spacer()
                Text(store.appVersion)
                    .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 5) {
                store.send(.aboutSectionLongPressed)
            }
        }
    }

    @ViewBuilder
    private var debugFormSection: some View {
        Section(header: Text("Debug")) {
            HStack {
                Text("Data Mode")
                Spacer()
                Text(store.dataModeDescription)
                    .foregroundColor(.gray)
            }

            HStack {
                Text("iCloud Container")
                Spacer()
                Text(store.iCloudContainerDescription)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.trailing)
            }

            Text("Last CloudKit Event: \(store.cloudDiagnosticsTimestamp)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(store.cloudDiagnosticsSummary)
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(store.pushDiagnosticsStatus)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

#if os(macOS)
    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    private var macSettingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.largeTitle.weight(.semibold))

                macSectionCard(title: "Notifications") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable notifications", isOn: notificationsBinding)
                            .toggleStyle(.switch)

                        DatePicker(
                            "Reminder time",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .disabled(store.notificationsEnabled == false)

                        Text("Notifications include quick actions for Done and Snooze.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if store.systemSettingsNotificationsEnabled == false {
                            Text("Notifications are disabled in system settings.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button("Allow in System Settings") {
                                store.send(.openAppSettingsTapped)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                macSectionCard(title: "App Icon") {
                    VStack(alignment: .leading, spacing: 14) {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 118), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(AppIconOption.allCases) { option in
                                macAppIconButton(option)
                            }
                        }

                        Text("Changes the Dock and app switcher icon immediately. Finder keeps the bundled app icon.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                macSectionCard(title: "Support") {
                    Button {
                        store.send(.contactUsTapped)
                    } label: {
                        Label("Contact Us", systemImage: "envelope")
                    }
                    .buttonStyle(.bordered)
                }

                macSectionCard(title: "iCloud") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                store.send(.syncNowTapped)
                            } label: {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath.icloud")
                            }
                            .buttonStyle(.bordered)
                            .disabled(
                                store.isCloudSyncInProgress ||
                                store.isCloudDataResetInProgress ||
                                !store.cloudSyncAvailable
                            )

                            Button(role: .destructive) {
                                store.send(.setCloudDataResetConfirmation(true))
                            } label: {
                                Label("Delete iCloud Data", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .disabled(
                                store.isCloudSyncInProgress ||
                                store.isCloudDataResetInProgress ||
                                !store.cloudSyncAvailable
                            )

                            if store.isCloudSyncInProgress || store.isCloudDataResetInProgress {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        Text(syncStatusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                macSectionCard(title: "Data Backup") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Button {
                                store.send(.exportRoutineDataTapped)
                            } label: {
                                Label("Save JSON", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.isDataTransferInProgress)

                            Button {
                                store.send(.importRoutineDataTapped)
                            } label: {
                                Label("Load JSON", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.isDataTransferInProgress)

                            if store.isDataTransferInProgress {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        Text(dataTransferStatusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                macSectionCard(title: "About") {
                    VStack(alignment: .leading, spacing: 8) {
                        macInfoRow(title: "App Version", value: store.appVersion)
                    }
                }
                .onLongPressGesture(minimumDuration: 5) {
                    store.send(.aboutSectionLongPressed)
                }

                if store.isDebugSectionVisible {
                    macSectionCard(title: "Debug") {
                        VStack(alignment: .leading, spacing: 8) {
                            macInfoRow(title: "Data Mode", value: store.dataModeDescription)
                            macInfoRow(title: "iCloud Container", value: store.iCloudContainerDescription)
                            Text("Last CloudKit Event: \(store.cloudDiagnosticsTimestamp)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(store.cloudDiagnosticsSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(store.pushDiagnosticsStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func macSectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(sectionCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func macInfoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func macAppIconButton(_ option: AppIconOption) -> some View {
        let isSelected = store.selectedAppIcon == option

        Button {
            store.send(.appIconSelected(option))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(option.assetName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 6) {
                    Text(option.title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : sectionCardStroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
#endif
}
