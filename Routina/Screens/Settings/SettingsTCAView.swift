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
                    }
                    
                    Section {
                        Button("Open app settings") {
                            viewStore.send(.openAppSettingsTapped)
                        }
                    }

                    Section(header: Text("Support")) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.blue)
                                Text("Contact Us")
                            }
                        }
                    }
                    aboutSectionView
                }
                .navigationTitle("Settings")
            }
        }
    }

    private var aboutSectionView: some View {
        Section(header: Text("About")) {
            HStack {
                Text("App Version")
                Spacer()
                Text("000")
                    .foregroundColor(.gray)
            }
        }
    }
}
