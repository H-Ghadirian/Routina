import ComposableArchitecture
import SwiftUI

struct SettingsTCAView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationView {
                Form {
                    Section(header: Text("Notifications")) {
                        Toggle("Enable notifications", isOn: viewStore.binding(
                            get: \.notificationsEnabled,
                            send: SettingsFeature.Action.toggleNotifications
                        ))
                        .disabled(viewStore.systemSettingsNotificationsEnabled == false)

                        if viewStore.systemSettingsNotificationsEnabled == false {
                            Button("Allow Notifications in System Settings") {
                                viewStore.send(.openAppSettingsTapped)
                            }
                            .foregroundColor(.red)
                        }
                    }

                    Section(header: Text("Support")) {
                        Button(action: {
                            viewStore.send(.contactUsTapped)
                        }) {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.blue)
                                Text("Contact Us")
                            }
                        }
                    }

                    Section(header: Text("iCloud")) {
                        Button {
                            viewStore.send(.syncNowTapped)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                    .foregroundColor(.blue)
                                Text("Sync Now")
                            }
                        }
                        .disabled(viewStore.isCloudSyncInProgress)

                        if viewStore.isCloudSyncInProgress {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Syncing...")
                                    .foregroundColor(.secondary)
                            }
                        } else if !viewStore.cloudSyncStatusMessage.isEmpty {
                            Text(viewStore.cloudSyncStatusMessage)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }

                    Section(header: Text("About")) {
                        HStack {
                            Text("App Version")
                            Spacer()
                            Text(viewStore.appVersion)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .navigationTitle("Settings")
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            ) { _ in
                viewStore.send(.onAppBecameActive)
            }
        }
    }
}
