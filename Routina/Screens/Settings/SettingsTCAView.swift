import ComposableArchitecture
import SwiftUI

struct SettingsTCAView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationView {
                Form {
                    Section(header: Text("Notifications")) {
                        Toggle(
                            "Enable notifications",
                            isOn: Binding(
                                get: { store.notificationsEnabled },
                                set: { store.send(.toggleNotifications($0)) }
                            )
                        )
                        .disabled(store.systemSettingsNotificationsEnabled == false)

                        if store.systemSettingsNotificationsEnabled == false {
                            Button("Allow Notifications in System Settings") {
                                store.send(.openAppSettingsTapped)
                            }
                            .foregroundColor(.red)
                        }
                    }

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
                .navigationTitle("Settings")
            }
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
}
