import ComposableArchitecture
import SwiftUI

struct SettingsTCAView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            settingsContent
            .onAppear {
                store.send(.onAppear)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
            ) { _ in
                store.send(.onAppBecameActive)
            }
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.notificationsEnabled },
            set: { store.send(.toggleNotifications($0)) }
        )
    }

    private var syncStatusText: String {
        if store.isCloudSyncInProgress {
            return "Syncing..."
        }
        if !store.cloudSyncStatusMessage.isEmpty {
            return store.cloudSyncStatusMessage
        }
        if !store.cloudSyncAvailable {
            return "iCloud sync is disabled in this build."
        }
        return "Ready to sync."
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
            }
            .navigationTitle("Settings")
        }
        #endif
    }

    @ViewBuilder
    private var notificationsFormSection: some View {
        Section(header: Text("Notifications")) {
            Toggle("Enable notifications", isOn: notificationsBinding)
                .disabled(store.systemSettingsNotificationsEnabled == false)

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
            .disabled(store.isCloudSyncInProgress || !store.cloudSyncAvailable)

            if store.isCloudSyncInProgress {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Syncing...")
                        .foregroundColor(.secondary)
                }
            } else if !store.cloudSyncStatusMessage.isEmpty {
                Text(store.cloudSyncStatusMessage)
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

            HStack {
                Text("Data Mode")
                Spacer()
                Text(store.dataModeDescription)
                    .foregroundColor(.gray)
            }
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
                            .disabled(store.systemSettingsNotificationsEnabled == false)

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
                            .disabled(store.isCloudSyncInProgress || !store.cloudSyncAvailable)

                            if store.isCloudSyncInProgress {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        Text(syncStatusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                macSectionCard(title: "About") {
                    VStack(alignment: .leading, spacing: 8) {
                        macInfoRow(title: "App Version", value: store.appVersion)
                        macInfoRow(title: "Data Mode", value: store.dataModeDescription)
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
#endif
}
